# Project Configuration
project_name        = "alexedftest"
resource_group_name = "rg-alexedftest"
location            = "ukwest"

# Storage Account Names (must be globally unique)
# Use lowercase alphanumeric only, 3-24 characters
preprocess_storage_name  = "alexdemopre"
postprocess_storage_name = "alexdemopost"
function_storage_name    = "alexdemofunc"

# Key Vault Name (must be globally unique)
keyvault_name = "kv-alexedftest"

# Function App Name (must be globally unique)
function_app_name = "func-alexedftest"

# User Principal Names
user_jess_upn = "jess.admin@achandlerzhugmail.onmicrosoft.com"
user_jeff_upn = "jeff.developer@achandlerzhugmail.onmicrosoft.com"
user_bob_upn  = "bob.reader@achandlerzhugmail.onmicrosoft.com"
user_raj_upn  = "raj.client@achandlerzhugmail.onmicrosoft.com"

# Tags
tags = {
  Environment = "Production"
  Purpose     = "VM-SQL-Tracking"
  ManagedBy   = "Terraform"
}
