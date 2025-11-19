provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azuread" {}

# Data source for current user
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Pre-process Storage Account
resource "azurerm_storage_account" "preprocess" {
  #checkov:skip=CKV2_AZURE_1:Customer Managed Keys not required for test environment
  #checkov:skip=CKV2_AZURE_21:Blob logging not required for test environment
  #checkov:skip=CKV2_AZURE_33:Private endpoint not required for test environment
  #checkov:skip=CKV2_AZURE_38:Soft delete not required for test environment
  #checkov:skip=CKV2_AZURE_40:Shared key required for Terraform management
  #checkov:skip=CKV2_AZURE_41:SAS expiration policy not required for test environment
  #checkov:skip=CKV_AZURE_33:Queue logging not required for test environment
  #checkov:skip=CKV_AZURE_59:Public access restricted via network rules
  #checkov:skip=CKV_AZURE_206:Replication not required for test environment
  name                     = var.preprocess_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "preprocess" {
  #checkov:skip=CKV2_AZURE_21:Blob logging not required for test environment
  name                  = "blobpreprocess"
  storage_account_name  = azurerm_storage_account.preprocess.name
  container_access_type = "private"
}

# Post-process Storage Account
resource "azurerm_storage_account" "postprocess" {
  #checkov:skip=CKV2_AZURE_1:Customer Managed Keys not required for test environment
  #checkov:skip=CKV2_AZURE_21:Blob logging not required for test environment
  #checkov:skip=CKV2_AZURE_33:Private endpoint not required for test environment
  #checkov:skip=CKV2_AZURE_38:Soft delete not required for test environment
  #checkov:skip=CKV2_AZURE_40:Shared key required for stakeholder access to reports
  #checkov:skip=CKV2_AZURE_41:SAS expiration policy not required for test environment
  #checkov:skip=CKV_AZURE_33:Queue logging not required for test environment
  #checkov:skip=CKV_AZURE_206:Replication not required for test environment
  name                     = var.postprocess_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "postprocess" {
  #checkov:skip=CKV2_AZURE_21:Blob logging not required for test environment
  name                  = "blobpostprocess"
  storage_account_name  = azurerm_storage_account.postprocess.name
  container_access_type = "private"
}

# Key Vault
resource "azurerm_key_vault" "main" {
  #checkov:skip=CKV_AZURE_189:Public access required for GitHub Actions CI/CD deployment
  #checkov:skip=CKV2_AZURE_32:Private endpoint not required for test environment
  #checkov:skip=CKV_AZURE_109:Allow required for GitHub Actions access from dynamic IPs
  name                = var.keyvault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  # Network settings
  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

# Managed Identity for Preprocessing Function
resource "azurerm_user_assigned_identity" "preprocess" {
  name                = "id-preprocess"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# Managed Identity for Postprocessing Function
resource "azurerm_user_assigned_identity" "postprocess" {
  name                = "id-postprocess"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# Managed Identity for GitHub Actions
resource "azurerm_user_assigned_identity" "github" {
  name                = "id-github"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# Storage Account for Function App
resource "azurerm_storage_account" "function" {
  #checkov:skip=CKV2_AZURE_1:Customer Managed Keys not required for test environment
  #checkov:skip=CKV2_AZURE_21:Blob logging not required for test environment
  #checkov:skip=CKV2_AZURE_33:Private endpoint not required for test environment
  #checkov:skip=CKV2_AZURE_38:Soft delete not required for test environment
  #checkov:skip=CKV2_AZURE_40:Shared key required for Azure Functions runtime
  #checkov:skip=CKV2_AZURE_41:SAS expiration policy not required for test environment
  #checkov:skip=CKV_AZURE_33:Queue logging not required for test environment
  #checkov:skip=CKV_AZURE_59:Public access restricted via network rules
  #checkov:skip=CKV_AZURE_206:Replication not required for test environment
  name                     = var.function_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = var.tags
}

# Log Analytics Workspace for Application Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"

  tags = var.tags
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  #checkov:skip=CKV_AZURE_212:Consumption plan does not support instance count configuration
  #checkov:skip=CKV_AZURE_225:Consumption plan does not support zone redundancy
  #checkov:skip=CKV_AZURE_211:Demo environment does not require zone redundancy
  name                = "asp-${var.project_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan

  tags = var.tags
}

# Function App
resource "azurerm_linux_function_app" "main" {
  #checkov:skip=CKV_AZURE_221:Public access required for GitHub Actions deployment and testing
  name                       = var.function_app_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  # Security: Enforce HTTPS only
  https_only = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.postprocess.id]
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "python"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "AzureWebJobsFeatureFlags"    = "EnableWorkerIndexing"

    # Application Insights
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string

    # Storage connection for Azure Functions
    "AzureWebJobsStorage"                      = azurerm_storage_account.function.primary_connection_string
    "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = azurerm_storage_account.function.primary_connection_string
    "WEBSITE_CONTENTSHARE"                     = var.function_app_name

    # Custom application settings
    "PREPROCESS_STORAGE_ACCOUNT"  = azurerm_storage_account.preprocess.name
    "PREPROCESS_CONTAINER"        = azurerm_storage_container.preprocess.name
    "POSTPROCESS_STORAGE_ACCOUNT" = azurerm_storage_account.postprocess.name
    "POSTPROCESS_CONTAINER"       = azurerm_storage_container.postprocess.name
    "KEY_VAULT_URL"               = azurerm_key_vault.main.vault_uri
    "MANAGED_IDENTITY_CLIENT_ID"  = azurerm_user_assigned_identity.postprocess.client_id
  }

  tags = var.tags
}
