# Project Configuration
project_name        = "REPLACE"
resource_group_name = "REPLACE"
location            = "uksouth"

# Storage Account Names (must be globally unique)
# Use lowercase alphanumeric only, 3-24 characters
preprocess_storage_name  = "REPLACE"
postprocess_storage_name = "REPLACE"
function_storage_name    = "REPLACE"

# Key Vault Name (must be globally unique)
keyvault_name = "REPLACE"

# Function App Name (must be globally unique)
function_app_name = "REPLACE"

# User Principal Names
user_jess_upn = "REPLACE"
user_jeff_upn = "REPLACE"
user_bob_upn  = "REPLACE"
user_raj_upn  = "REPLACE"

# Tags
tags = {
  Environment = "Production"
  Purpose     = "VM-SQL-Tracking"
  ManagedBy   = "Terraform"
}
