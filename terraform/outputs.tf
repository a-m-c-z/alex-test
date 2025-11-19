# Terraform Outputs

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

# Storage Accounts
output "preprocess_storage_account_name" {
  description = "Pre-process storage account name"
  value       = azurerm_storage_account.preprocess.name
}

output "preprocess_container_name" {
  description = "Pre-process blob container name"
  value       = azurerm_storage_container.preprocess.name
}

output "postprocess_storage_account_name" {
  description = "Post-process storage account name"
  value       = azurerm_storage_account.postprocess.name
}

output "postprocess_container_name" {
  description = "Post-process blob container name"
  value       = azurerm_storage_container.postprocess.name
}

# Key Vault
output "keyvault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

# Function App
output "function_app_name" {
  description = "Function App name"
  value       = azurerm_linux_function_app.main.name
}

output "function_app_default_hostname" {
  description = "Function App default hostname"
  value       = azurerm_linux_function_app.main.default_hostname
}

# Managed Identities
output "postprocess_managed_identity_client_id" {
  description = "Postprocess function managed identity client ID"
  value       = azurerm_user_assigned_identity.postprocess.client_id
}

output "postprocess_managed_identity_principal_id" {
  description = "Postprocess function managed identity principal ID"
  value       = azurerm_user_assigned_identity.postprocess.principal_id
}

output "github_managed_identity_client_id" {
  description = "GitHub Actions managed identity client ID"
  value       = azurerm_user_assigned_identity.github.client_id
}

# Application Insights
output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# Deployment Information
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group      = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location
    preprocess_storage  = azurerm_storage_account.preprocess.name
    postprocess_storage = azurerm_storage_account.postprocess.name
    key_vault           = azurerm_key_vault.main.name
    function_app        = azurerm_linux_function_app.main.name
  }
}
