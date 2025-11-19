"""
Pytest configuration and shared fixtures.

This file contains shared test fixtures and configuration
for the test suite.
"""

import pytest


@pytest.fixture(autouse=True)
def reset_environment():
    """
    Reset environment variables after each test to ensure test isolation.

    This fixture automatically runs before and after each test to prevent
    environment variable pollution between tests.
    """
    import os

    # Store original environment
    original_env = os.environ.copy()

    # Run the test
    yield

    # Restore original environment
    os.environ.clear()
    os.environ.update(original_env)


@pytest.fixture
def mock_azure_env():
    """
    Provide a complete set of mock Azure environment variables.

    Use this fixture when you need a full Azure configuration
    for testing.
    """
    return {
        "PREPROCESS_STORAGE_ACCOUNT": "preprocessstorage",
        "PREPROCESS_CONTAINER": "pre-container",
        "POSTPROCESS_STORAGE_ACCOUNT": "postprocessstorage",
        "POSTPROCESS_CONTAINER": "post-container",
        "KEY_VAULT_URL": "https://test-keyvault.vault.azure.net",
        "MANAGED_IDENTITY_CLIENT_ID": "test-client-id-12345",
    }


# Configure pytest logging
def pytest_configure(config):
    """Configure pytest with custom settings."""
    import logging

    logging.getLogger("azure").setLevel(logging.ERROR)
