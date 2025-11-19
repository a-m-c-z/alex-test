# Project Configuration
project_name        = "alexfinal"
resource_group_name = "rg-alexfinal2"
location            = "ukwest"

# Storage Account Names (must be globally unique)
# Use lowercase alphanumeric only, 3-24 characters
preprocess_storage_name  = "saalexfinalpre"
postprocess_storage_name = "saalexfinalpost"
function_storage_name    = "saalexfinalfunc"

# Key Vault Name (must be globally unique)
keyvault_name = "kv-alexfinal2"

# Function App Name (must be globally unique)
function_app_name = "func-edftest"

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
