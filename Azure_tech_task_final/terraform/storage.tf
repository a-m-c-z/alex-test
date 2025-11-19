# Storage resources for pre-processing and post-processing containers

# Azure Storage Account - where raw VM data is stored
resource "azurerm_storage_account" "preprocessing" {
  name                     = "vmsqlpreprocessing"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = "Production"
    Purpose     = "VM-SQL-Tracking"
  }
}

resource "azurerm_storage_account_blob_container_sas" "preprocessing" {
  container_name    = azurerm_storage_container.preprocessing.name
  connection_string = azurerm_storage_account.preprocessing.primary_connection_string
  https_only        = true

  start  = "2024-01-01"
  expiry = "2025-12-31"

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = true
    list   = true
  }
}

# Pre-processing container - where raw VM data is stored
resource "azurerm_storage_container" "preprocessing" {
  name                  = "preprocessing"
  storage_account_name  = azurerm_storage_account.preprocessing.name
  container_access_type = "private"
}

# Upload the password file to pre-processing container
resource "azurerm_storage_blob" "password" {
  name                   = "password.txt"
  storage_account_name   = azurerm_storage_account.preprocessing.name
  storage_container_name = azurerm_storage_container.preprocessing.name
  type                   = "Block"
  source                 = "${path.module}/../password.txt"
}

# Post-processing container - where filtered Excel reports are stored
# TODO: Implement post-processing container