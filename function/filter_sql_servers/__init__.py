"""
Azure Function to filter VM inventory for SQL Server installations.

This function:
1. Reads VM inventory CSV from pre-process blob storage
2. Filters for VMs with SQL Server installed
3. Writes filtered results to post-process blob storage as Excel file
4. Password-protects the Excel file using password from Key Vault

Trigger: HTTP (manual trigger)
"""

import logging
import os
import json
from io import BytesIO
from datetime import datetime
import azure.functions as func
from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient
from azure.keyvault.secrets import SecretClient
import pandas as pd
from openpyxl.styles import Font, PatternFill
from msoffcrypto import OfficeFile


class VMFilter:
    """
    Class to handle filtering of VMs with SQL Server and export to Excel.
    """

    def __init__(self, credential, config):
        """
        Initialize the VMFilter class.

        Args:
            credential: Azure managed identity credential
            config: Configuration dictionary with storage and Key Vault info
        """
        self.credential = credential
        self.config = config
        self.data = None

    def load_data(self, input_path):
        """
        Load VM data from CSV file in Azure Blob Storage.

        Args:
            input_path: Blob name of the input CSV file

        Returns:
            Loaded pandas DataFrame
        """
        logging.info(f"Loading data from {input_path}...")

        # Create blob client for pre-process storage
        preprocess_blob_url = (
            f"https://{self.config['preprocess_account']}"
            f".blob.core.windows.net"
        )
        preprocess_client = BlobServiceClient(
            account_url=preprocess_blob_url, credential=self.credential
        )
        preprocess_blob_client = preprocess_client.get_blob_client(
            container=self.config["preprocess_container"], blob=input_path
        )

        # Download and parse CSV
        csv_data = preprocess_blob_client.download_blob().readall()
        self.data = pd.read_csv(BytesIO(csv_data))

        logging.info(f"Loaded {len(self.data)} total VMs")
        return self.data

    def filter_sql_vms(self, data):
        """
        Return rows where SQLSoftware contains 'Microsoft SQL Server'.
        """
        logging.info("Filtering VMs for Microsoft SQL Server...")

        def contains_sql_server(val):
            # Handle None/NaN
            if val is None or (isinstance(val, float) and pd.isna(val)):
                return False

            # Handle string representations of empty lists
            if isinstance(val, str) and val.strip() in ("[]", ""):
                return False

            # If the column is already a list, check directly
            if isinstance(val, list):
                return any("Microsoft SQL Server" in s for s in val)

            # Otherwise treat as a string
            try:
                parsed = json.loads(val)
                return any("Microsoft SQL Server" in s for s in parsed)
            except Exception:
                # fallback: simple substring search
                return "Microsoft SQL Server" in str(val)

        mask = data["SQLSoftware"].apply(contains_sql_server)
        result = data[mask].copy()

        logging.info(
            f"Found {len(result)} VMs with Microsoft SQL Server installed."
        )
        return result

    def export_to_excel(self, data, output_path, password):
        """
        Export filtered data to password-protected Excel file and upload to
        blob storage.

        Args:
            data: Filtered VM pandas DataFrame
            output_path: Blob name to save the Excel file
            password: Password to protect the Excel file (REQUIRED)
        """
        logging.info(f"Exporting {len(data)} VMs to Excel...")

        if "AccountID" in data.columns:
            data = data.copy()
            data["AccountID"] = data["AccountID"].astype(str)

        # Create Excel file with formatting - AI used for formatting code
        excel_buffer = BytesIO()
        with pd.ExcelWriter(excel_buffer, engine="openpyxl") as writer:
            data.to_excel(writer, index=False, sheet_name="SQL Servers")

            # Format the Excel sheet
            workbook = writer.book
            worksheet = writer.sheets["SQL Servers"]

            # Header formatting
            header_fill = PatternFill(
                start_color="0066CC", end_color="0066CC", fill_type="solid"
            )
            header_font = Font(bold=True, color="FFFFFF")

            for cell in worksheet[1]:
                cell.fill = header_fill
                cell.font = header_font

            # Auto-adjust column widths
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        cell_len = len(str(cell.value))
                        if cell_len > max_length:
                            max_length = cell_len
                    # Column-width logic is unreachable in unit tests due to
                    # pandas/openpyxl lazy worksheet population
                    except Exception:  # pragma: no cover
                        pass  # pragma: no cover
                adjusted_width = min(max_length + 2, 50)
                worksheet.column_dimensions[column_letter].width = (
                    adjusted_width
                )

        excel_buffer.seek(0)

        # Apply password protection
        logging.info("Applying password protection to Excel file...")
        protected_buffer = BytesIO()
        office_file = OfficeFile(excel_buffer)
        office_file.load_key(password=password)
        office_file.encrypt(password, protected_buffer)
        protected_buffer.seek(0)
        logging.info("Password protection applied successfully")

        # Upload to post-process storage
        logging.info(f"Uploading password-protected file to {output_path}...")
        postprocess_blob_url = f"https://{self.config['postprocess_account']}.blob.core.windows.net"
        postprocess_client = BlobServiceClient(
            account_url=postprocess_blob_url, credential=self.credential
        )
        postprocess_blob_client = postprocess_client.get_blob_client(
            container=self.config["postprocess_container"], blob=output_path
        )

        postprocess_blob_client.upload_blob(
            protected_buffer.read(), overwrite=True
        )

        logging.info(f"Successfully uploaded {output_path}")


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Main function to orchestrate the VM filtering process.
    """
    logging.info("SQL Server filter function triggered")

    try:
        # Get configuration from environment variables
        config = {
            "preprocess_account": os.environ["PREPROCESS_STORAGE_ACCOUNT"],
            "preprocess_container": os.environ["PREPROCESS_CONTAINER"],
            "postprocess_account": os.environ["POSTPROCESS_STORAGE_ACCOUNT"],
            "postprocess_container": os.environ["POSTPROCESS_CONTAINER"],
            "keyvault_url": os.environ.get("KEY_VAULT_URL"),
            "managed_identity_client_id": os.environ[
                "MANAGED_IDENTITY_CLIENT_ID"
            ],
        }

        # Authenticate using managed identity
        credential = ManagedIdentityCredential(
            client_id=config["managed_identity_client_id"]
        )

        # Initialize VM filter
        vm_filter = VMFilter(credential, config)

        # Load data from pre-process storage
        input_file = "vm_inventory.csv"
        data = vm_filter.load_data(input_file)

        # Filter VMs with SQL Server
        sql_vms = vm_filter.filter_sql_vms(data)

        if sql_vms.empty:
            logging.warning("No SQL Server installations found")
            return func.HttpResponse(
                "No SQL Server installations found in inventory",
                status_code=200,
            )

        # Retrieve password from Key Vault (MANDATORY)
        if not config.get("keyvault_url"):
            logging.error("KEY_VAULT_URL not configured")
            return func.HttpResponse(
                "Configuration error: KEY_VAULT_URL is required",
                status_code=500,
            )

        logging.info("Retrieving password from Key Vault...")
        secret_client = SecretClient(
            vault_url=config["keyvault_url"], credential=credential
        )
        password_secret = secret_client.get_secret("postprocess-secret")
        password = password_secret.value
        logging.info("Password retrieved successfully")

        # Export to Excel with optional password protection
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = f"sql_servers_report_{timestamp}.xlsx"
        vm_filter.export_to_excel(sql_vms, output_file, password)

        logging.info(
            f"Successfully created report with {len(sql_vms)} "
            f"SQL Server VMs"
        )

        return func.HttpResponse(
            f"Report generated successfully: {output_file}\n"
            f"Total SQL Server VMs: {len(sql_vms)}\n"
            f"File is password-protected using Key Vault secret",
            status_code=200,
        )

    except KeyError as e:
        logging.error(f"Missing configuration: {str(e)}")
        return func.HttpResponse(
            f"Configuration error: Missing {str(e)}", status_code=500
        )
    except Exception as e:
        logging.error(
            f"Error processing SQL Server report: {str(e)}", exc_info=True
        )
        return func.HttpResponse(f"Error: {str(e)}", status_code=500)
