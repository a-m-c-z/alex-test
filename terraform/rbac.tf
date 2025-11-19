# RBAC Role Assignments
# This file manages all Azure RBAC role assignments for the task.
# Note in real-world use cases, I would prefer to assign to Azure Groups.


# Lookup users from EntraID
data "azuread_user" "jess" {
  user_principal_name = var.user_jess_upn
}

data "azuread_user" "jeff" {
  user_principal_name = var.user_jeff_upn
}

data "azuread_user" "bob" {
  user_principal_name = var.user_bob_upn
}

data "azuread_user" "raj" {
  user_principal_name = var.user_raj_upn
}

# ============================================================================
# Jess Admin - Full Control
# ============================================================================

# Pre-process Storage Account
resource "azurerm_role_assignment" "jess_preprocess_owner" {
  scope                = azurerm_storage_account.preprocess.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azuread_user.jess.object_id
}

# Post-process Storage Account
resource "azurerm_role_assignment" "jess_postprocess_owner" {
  scope                = azurerm_storage_account.postprocess.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azuread_user.jess.object_id
}

# Key Vault
resource "azurerm_role_assignment" "jess_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_user.jess.object_id
}

# Function App
resource "azurerm_role_assignment" "jess_function_contributor" {
  scope                = azurerm_linux_function_app.main.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_user.jess.object_id
}

# Resource Group (for infrastructure management)
resource "azurerm_role_assignment" "jess_rg_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_user.jess.object_id
}

# ============================================================================
# Jeff Developer - Maintain Solution
# ============================================================================

# Pre-process Storage Account
resource "azurerm_role_assignment" "jeff_preprocess_contributor" {
  scope                = azurerm_storage_account.preprocess.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_user.jeff.object_id
}

# Post-process Storage Account
resource "azurerm_role_assignment" "jeff_postprocess_contributor" {
  scope                = azurerm_storage_account.postprocess.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_user.jeff.object_id
}

# Key Vault
resource "azurerm_role_assignment" "jeff_keyvault_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azuread_user.jeff.object_id
}

# Function App - Monitoring Reader
resource "azurerm_role_assignment" "jeff_function_monitoring" {
  scope                = azurerm_linux_function_app.main.id
  role_definition_name = "Monitoring Reader"
  principal_id         = data.azuread_user.jeff.object_id
}

# Function App - Website Contributor (restart capability)
resource "azurerm_role_assignment" "jeff_function_website" {
  scope                = azurerm_linux_function_app.main.id
  role_definition_name = "Website Contributor"
  principal_id         = data.azuread_user.jeff.object_id
}

# ============================================================================
# Bob Reader - Extract Reports
# ============================================================================

resource "azurerm_role_assignment" "bob_postprocess_reader" {
  scope                = azurerm_storage_account.postprocess.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_user.bob.object_id
}

# ============================================================================
# Raj Client - Consume Reports
# ============================================================================

resource "azurerm_role_assignment" "raj_postprocess_reader" {
  scope                = azurerm_storage_account.postprocess.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = data.azuread_user.raj.object_id
}

# ============================================================================
# Managed Identity - Postprocess Function
# ============================================================================

# Pre-process Storage - Read access
resource "azurerm_role_assignment" "function_preprocess_reader" {
  scope                = azurerm_storage_account.preprocess.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.postprocess.principal_id
}

# Post-process Storage - Write access
resource "azurerm_role_assignment" "function_postprocess_contributor" {
  scope                = azurerm_storage_account.postprocess.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.postprocess.principal_id
}

# Key Vault - Read secrets
resource "azurerm_role_assignment" "function_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.postprocess.principal_id
}

# ============================================================================
# GitHub Actions Service Principal (for CI/CD)
# ============================================================================

# Function App - Deployment
resource "azurerm_role_assignment" "github_function_contributor" {
  scope                = azurerm_linux_function_app.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}

# Storage Account - Deploy function packages
resource "azurerm_role_assignment" "github_function_storage" {
  scope                = azurerm_storage_account.function.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}

# Key Vault - For deployment secrets if needed
resource "azurerm_role_assignment" "github_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}

# Allow deployer to manage Key Vault for initial setup
resource "azurerm_role_assignment" "deployer_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
