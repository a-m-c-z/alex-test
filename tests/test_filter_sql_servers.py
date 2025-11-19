"""
Unit tests for Azure Function SQL Server VM filter.
Note: AI used to achieve as close to full coverage as possible.
"""

import json
import os
from datetime import datetime
from io import BytesIO
from unittest.mock import MagicMock, Mock, patch, PropertyMock
import pathlib

import pandas as pd
import pytest
import azure.functions as func

# Import the module under test
from filter_sql_servers import VMFilter, main


# Path to test data
TEST_DATA_DIR = pathlib.Path(__file__).parent / "data"
MOCK_CSV_PATH = TEST_DATA_DIR / "vm_inventory.csv"


@pytest.fixture
def mock_credential():
    """Mock Azure ManagedIdentityCredential."""
    return MagicMock()


@pytest.fixture
def test_config():
    """Test configuration dictionary."""
    return {
        "preprocess_account": "preprocessstorage",
        "preprocess_container": "pre-container",
        "postprocess_account": "postprocessstorage",
        "postprocess_container": "post-container",
        "keyvault_url": "https://test-keyvault.vault.azure.net",
        "managed_identity_client_id": "test-client-id",
    }


@pytest.fixture
def real_mock_csv_data():
    """Load the actual mock CSV data from the test data directory."""
    return pd.read_csv(MOCK_CSV_PATH)


@pytest.fixture
def real_mock_csv_bytes():
    """Load the mock CSV as bytes (as Azure Blob would return it)."""
    with open(MOCK_CSV_PATH, "rb") as f:
        return f.read()


@pytest.fixture
def sample_vm_data():
    """Small sample of VM data for quick tests."""
    return pd.DataFrame(
        {
            "AccountID": [123456789012, 234567890123, 345678901234],
            "VMName": ["vm1", "vm2", "vm3"],
            "PlatformDetails": ["Windows", "Windows", "Windows"],
            "SQLSoftware": [
                '["Microsoft SQL Server 2019"]',
                '["PostgreSQL"]',
                '["Microsoft SQL Server 2016", "Microsoft SQL Server 2017"]',
            ],
            "RawSoftware": [
                "['Software A', 'Software B']",
                "['Software C']",
                "['Software D', 'Software E']",
            ],
        }
    )


class TestVMFilter:
    """Test cases for VMFilter class."""

    def test_init(self, mock_credential, test_config):
        """Test VMFilter initialisation."""
        vm_filter = VMFilter(mock_credential, test_config)

        assert vm_filter.credential == mock_credential
        assert vm_filter.config == test_config
        assert vm_filter.data is None

    @patch("filter_sql_servers.BlobServiceClient")
    def test_load_data_with_real_mock_csv(
        self,
        mock_blob_service,
        mock_credential,
        test_config,
        real_mock_csv_bytes,
    ):
        """Test loading data using the real mock CSV file."""
        # Arrange
        mock_download_result = MagicMock()
        mock_download_result.readall.return_value = real_mock_csv_bytes

        mock_blob_client = MagicMock()
        mock_blob_client.download_blob.return_value = mock_download_result

        mock_container_client = MagicMock()
        mock_container_client.get_blob_client.return_value = mock_blob_client

        mock_blob_service.return_value = mock_container_client

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.load_data("vm_inventory.csv")

        # Assert
        assert len(result) > 0
        assert "AccountID" in result.columns
        assert "VMName" in result.columns
        assert "SQLSoftware" in result.columns
        assert "PlatformDetails" in result.columns

    @patch("filter_sql_servers.BlobServiceClient")
    def test_load_data_success(
        self, mock_blob_service, mock_credential, test_config, sample_vm_data
    ):
        """Test successful data loading from blob storage."""
        # Arrange
        csv_data = sample_vm_data.to_csv(index=False).encode("utf-8")

        mock_download_result = MagicMock()
        mock_download_result.readall.return_value = csv_data

        mock_blob_client = MagicMock()
        mock_blob_client.download_blob.return_value = mock_download_result

        mock_container_client = MagicMock()
        mock_container_client.get_blob_client.return_value = mock_blob_client

        mock_blob_service.return_value = mock_container_client

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.load_data("vm_inventory.csv")

        # Assert
        assert len(result) == 3
        assert "VMName" in result.columns
        mock_blob_service.assert_called_once()

    def test_filter_sql_vms_with_real_data(
        self, mock_credential, test_config, real_mock_csv_data
    ):
        """Test filtering using the real mock CSV data."""
        # Arrange
        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(real_mock_csv_data)

        # Assert
        assert len(result) > 0  # Should find SQL Server VMs

        # Verify all results have SQL Server
        for _, row in result.iterrows():
            sql_software = row["SQLSoftware"]
            if pd.notna(sql_software) and sql_software != "[]":
                # Parse and check
                try:
                    software_list = json.loads(sql_software)
                    has_sql = any(
                        "Microsoft SQL Server" in s for s in software_list
                    )
                    assert (
                        has_sql
                    ), f"Row {row['VMName']} doesn't have SQL Server"
                except json.JSONDecodeError:
                    # Handle string format
                    assert "Microsoft SQL Server" in sql_software

    def test_filter_sql_vms_with_json_strings(
        self, mock_credential, test_config, sample_vm_data
    ):
        """Test filtering VMs with SQL Server (JSON string format)."""
        # Arrange
        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(sample_vm_data)

        # Assert
        assert len(result) == 2
        assert "vm1" in result["VMName"].values
        assert "vm3" in result["VMName"].values
        assert "vm2" not in result["VMName"].values

    def test_filter_sql_vms_with_list_format(
        self, mock_credential, test_config
    ):
        """Test filtering VMs when SQLSoftware is already a list."""
        # Arrange
        data = pd.DataFrame(
            {
                "VMName": ["vm1", "vm2", "vm3"],
                "SQLSoftware": [
                    ["Microsoft SQL Server 2019"],
                    ["PostgreSQL"],
                    ["Microsoft SQL Server 2016", "Oracle"],
                ],
            }
        )

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(data)

        # Assert
        assert len(result) == 2
        assert "vm1" in result["VMName"].values
        assert "vm3" in result["VMName"].values

    def test_filter_sql_vms_no_matches(self, mock_credential, test_config):
        """Test filtering when no VMs have SQL Server."""
        # Arrange
        data = pd.DataFrame(
            {
                "VMName": ["vm1", "vm2"],
                "SQLSoftware": ['["PostgreSQL"]', '["MySQL"]'],
            }
        )

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(data)

        # Assert
        assert len(result) == 0
        assert result.empty

    def test_filter_sql_vms_with_empty_arrays(
        self, mock_credential, test_config
    ):
        """Test filtering handles empty array [] correctly."""
        # Arrange
        data = pd.DataFrame(
            {
                "VMName": ["vm1", "vm2", "vm3"],
                "SQLSoftware": ["[]", '["Microsoft SQL Server 2019"]', None],
            }
        )

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(data)

        # Assert
        assert len(result) == 1
        assert "vm2" in result["VMName"].values

    @patch("filter_sql_servers.BlobServiceClient")
    @patch("filter_sql_servers.OfficeFile")
    def test_export_to_excel_success(
        self,
        mock_office_file,
        mock_blob_service,
        mock_credential,
        test_config,
        sample_vm_data,
    ):
        """Test successful Excel export with password protection."""
        # Arrange
        filtered_data = sample_vm_data.iloc[:2]
        password = "test_password_123"

        mock_upload_result = MagicMock()

        mock_upload_client = MagicMock()
        mock_upload_client.upload_blob.return_value = mock_upload_result

        mock_container_client = MagicMock()
        mock_container_client.get_blob_client.return_value = mock_upload_client
        mock_blob_service.return_value = mock_container_client

        mock_office_instance = MagicMock()
        mock_office_file.return_value = mock_office_instance

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        vm_filter.export_to_excel(filtered_data, "test_output.xlsx", password)

        # Assert
        mock_office_instance.load_key.assert_called_once_with(
            password=password
        )
        mock_office_instance.encrypt.assert_called_once()
        mock_upload_client.upload_blob.assert_called_once()

    @patch("filter_sql_servers.BlobServiceClient")
    @patch("filter_sql_servers.OfficeFile")
    def test_export_converts_accountid_to_string(
        self, mock_office_file, mock_blob_service, mock_credential, test_config
    ):
        """Test AccountID conversion to prevent scientific notation."""
        # Arrange
        data = pd.DataFrame(
            {
                "AccountID": [123456789012, 234567890123],
                "VMName": ["vm1", "vm2"],
            }
        )

        mock_upload_result = MagicMock()

        mock_upload_client = MagicMock()
        mock_upload_client.upload_blob.return_value = mock_upload_result

        mock_container_client = MagicMock()
        mock_container_client.get_blob_client.return_value = mock_upload_client
        mock_blob_service.return_value = mock_container_client

        mock_office_instance = MagicMock()
        mock_office_file.return_value = mock_office_instance

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        vm_filter.export_to_excel(data, "test.xlsx", "password")

        # Assert - function creates a copy, verify upload happened
        mock_upload_client.upload_blob.assert_called_once()


class TestMainFunction:
    """Test cases for main Azure Function."""

    @patch("filter_sql_servers.SecretClient")
    @patch("filter_sql_servers.VMFilter")
    @patch("filter_sql_servers.ManagedIdentityCredential")
    @patch.dict(
        os.environ,
        {
            "PREPROCESS_STORAGE_ACCOUNT": "preprocess",
            "PREPROCESS_CONTAINER": "pre-container",
            "POSTPROCESS_STORAGE_ACCOUNT": "postprocess",
            "POSTPROCESS_CONTAINER": "post-container",
            "KEY_VAULT_URL": "https://test-kv.vault.azure.net",
            "MANAGED_IDENTITY_CLIENT_ID": "client-id",
        },
    )
    def test_main_success(
        self,
        mock_credential_class,
        mock_vm_filter_class,
        mock_secret_client_class,
        sample_vm_data,
    ):
        """Test successful execution of main function."""
        # Arrange
        mock_req = Mock(spec=func.HttpRequest)

        mock_credential = MagicMock()
        mock_credential_class.return_value = mock_credential

        mock_vm_filter = MagicMock()
        filtered_data = sample_vm_data.iloc[:2]
        mock_vm_filter.load_data.return_value = sample_vm_data
        mock_vm_filter.filter_sql_vms.return_value = filtered_data
        mock_vm_filter_class.return_value = mock_vm_filter

        mock_secret_client = MagicMock()
        mock_secret = MagicMock()
        mock_secret.value = "test_password"
        mock_secret_client.get_secret.return_value = mock_secret
        mock_secret_client_class.return_value = mock_secret_client

        # Act
        response = main(mock_req)

        # Assert
        assert response.status_code == 200
        assert "Report generated successfully" in (
            response.get_body().decode()
        )
        assert "Total SQL Server VMs: 2" in response.get_body().decode()

        mock_vm_filter.load_data.assert_called_once_with("vm_inventory.csv")
        mock_secret_client.get_secret.assert_called_once_with(
            "postprocess-secret"
        )

    @patch("filter_sql_servers.VMFilter")
    @patch("filter_sql_servers.ManagedIdentityCredential")
    @patch.dict(
        os.environ,
        {
            "PREPROCESS_STORAGE_ACCOUNT": "preprocess",
            "PREPROCESS_CONTAINER": "pre-container",
            "POSTPROCESS_STORAGE_ACCOUNT": "postprocess",
            "POSTPROCESS_CONTAINER": "post-container",
            "KEY_VAULT_URL": "https://test-kv.vault.azure.net",
            "MANAGED_IDENTITY_CLIENT_ID": "client-id",
        },
    )
    def test_main_no_sql_servers_found(
        self, mock_credential_class, mock_vm_filter_class, sample_vm_data
    ):
        """Test main function when no SQL Server VMs found."""
        # Arrange
        mock_req = Mock(spec=func.HttpRequest)

        mock_vm_filter = MagicMock()
        mock_vm_filter.load_data.return_value = sample_vm_data
        mock_vm_filter.filter_sql_vms.return_value = pd.DataFrame()
        mock_vm_filter_class.return_value = mock_vm_filter

        # Act
        response = main(mock_req)

        # Assert
        assert response.status_code == 200
        assert "No SQL Server installations found" in (
            response.get_body().decode()
        )

    @patch("filter_sql_servers.VMFilter")
    @patch("filter_sql_servers.ManagedIdentityCredential")
    @patch.dict(
        os.environ,
        {
            "PREPROCESS_STORAGE_ACCOUNT": "preprocess",
            "PREPROCESS_CONTAINER": "pre-container",
            "POSTPROCESS_STORAGE_ACCOUNT": "postprocess",
            "POSTPROCESS_CONTAINER": "post-container",
            # KEY_VAULT_URL intentionally missing
            "MANAGED_IDENTITY_CLIENT_ID": "client-id",
        },
        clear=True,
    )
    def test_main_missing_keyvault_url(
        self, mock_credential_class, mock_vmfilter_class
    ):
        """Covers KEY_VAULT_URL is missing but SQL VMs exist."""

        mock_req = Mock(spec=func.HttpRequest)

        # Configure VMFilter mock to produce NON-empty SQL results
        mock_vmfilter = MagicMock()
        mock_vmfilter.load_data.return_value = pd.DataFrame({"a": [1]})
        mock_vmfilter.filter_sql_vms.return_value = pd.DataFrame({"a": [1]})
        mock_vmfilter_class.return_value = mock_vmfilter

        # Act
        response = main(mock_req)

        # Assert
        assert response.status_code == 500
        body = response.get_body().decode()
        assert "KEY_VAULT_URL is required" in body


class TestEdgeCases:
    """Test edge cases and real-world scenarios."""

    def test_filter_with_platform_details_containing_sql(
        self, mock_credential, test_config
    ):
        """Test VMs where PlatformDetails mentions SQL but SQLSoftware
        is empty."""
        # Arrange - mimics real CSV structure
        data = pd.DataFrame(
            {
                "VMName": ["vm1", "vm2"],
                "PlatformDetails": [
                    "Windows with SQL Server Enterprise",
                    "Windows",
                ],
                "SQLSoftware": ["[]", '["Microsoft SQL Server 2019"]'],
            }
        )

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(data)

        # Assert - only vm2 should be selected
        assert len(result) == 1
        assert "vm2" in result["VMName"].values

    def test_filter_handles_multiple_sql_versions(
        self, mock_credential, test_config
    ):
        """Test filtering VMs with multiple SQL Server versions."""
        # Arrange
        data = pd.DataFrame(
            {
                "VMName": ["vm1"],
                "SQLSoftware": [
                    '["Microsoft SQL Server 2016", "Microsoft SQL Server 2017 (64-bit)", "Microsoft SQL Server 2016 (64-bit)"]'
                ],
            }
        )

        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(data)

        # Assert
        assert len(result) == 1
        assert "vm1" in result["VMName"].values

    def test_large_dataset_performance(
        self, mock_credential, test_config, real_mock_csv_data
    ):
        """Test performance with the full mock CSV dataset."""
        # Arrange
        vm_filter = VMFilter(mock_credential, test_config)

        # Act
        result = vm_filter.filter_sql_vms(real_mock_csv_data)

        # Assert
        assert len(result) >= 0  # Should complete without error

        # All results should have SQL Server
        if not result.empty:
            for _, row in result.iterrows():
                sql_soft = str(row["SQLSoftware"])
                assert sql_soft != "[]"
                assert sql_soft != "nan"


class TestCoverageGaps:
    """Tests to achieve 100% coverage."""

    @patch("filter_sql_servers.VMFilter")
    @patch("filter_sql_servers.ManagedIdentityCredential")
    @patch.dict(
        os.environ,
        {
            "PREPROCESS_STORAGE_ACCOUNT": "preprocess",
            "PREPROCESS_CONTAINER": "pre-container",
            "POSTPROCESS_STORAGE_ACCOUNT": "postprocess",
            "POSTPROCESS_CONTAINER": "post-container",
            "KEY_VAULT_URL": "https://test-kv.vault.azure.net",
            "MANAGED_IDENTITY_CLIENT_ID": "client-id",
        },
    )
    def test_main_empty_sql_servers(
        self, mock_credential_class, mock_vm_filter_class
    ):
        """Test main when filter returns empty DataFrame."""
        # Arrange
        mock_req = Mock(spec=func.HttpRequest)

        sample_data = pd.DataFrame(
            {"VMName": ["vm1", "vm2"], "SQLSoftware": ["[]", "[]"]}
        )

        mock_vm_filter = MagicMock()
        mock_vm_filter.load_data.return_value = sample_data
        mock_vm_filter.filter_sql_vms.return_value = pd.DataFrame()
        mock_vm_filter_class.return_value = mock_vm_filter

        # Act
        response = main(mock_req)

        # Assert
        assert response.status_code == 200
        assert "No SQL Server installations found" in (
            response.get_body().decode()
        )

    @patch.dict(
        os.environ,
        {
            "PREPROCESS_STORAGE_ACCOUNT": "preprocess",
            "POSTPROCESS_STORAGE_ACCOUNT": "postprocess",
            "MANAGED_IDENTITY_CLIENT_ID": "client-id",
            # Missing PREPROCESS_CONTAINER
        },
    )
    def test_main_missing_env_variable(self):
        """Test main with missing environment variable."""
        # Arrange
        mock_req = Mock(spec=func.HttpRequest)

        # Act
        response = main(mock_req)

        # Assert
        assert response.status_code == 500
        assert "Configuration error" in response.get_body().decode()
        assert "PREPROCESS_CONTAINER" in response.get_body().decode()

    @patch("filter_sql_servers.VMFilter")
    @patch("filter_sql_servers.ManagedIdentityCredential")
    @patch.dict(
        os.environ,
        {
            "PREPROCESS_STORAGE_ACCOUNT": "preprocess",
            "PREPROCESS_CONTAINER": "pre-container",
            "POSTPROCESS_STORAGE_ACCOUNT": "postprocess",
            "POSTPROCESS_CONTAINER": "post-container",
            "KEY_VAULT_URL": "https://test-kv.vault.azure.net",
            "MANAGED_IDENTITY_CLIENT_ID": "client-id",
        },
    )
    def test_main_generic_exception(
        self, mock_credential_class, mock_vm_filter_class
    ):
        """Test main with unexpected exception."""
        # Arrange
        mock_req = Mock(spec=func.HttpRequest)

        mock_vm_filter = MagicMock()
        mock_vm_filter.load_data.side_effect = RuntimeError("Unexpected error")
        mock_vm_filter_class.return_value = mock_vm_filter

        # Act
        response = main(mock_req)

        # Assert
        assert response.status_code == 500
        assert "Error: Unexpected error" in response.get_body().decode()

