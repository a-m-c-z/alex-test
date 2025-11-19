# Core Variables
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "edf-sql-monitoring"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-edftest"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

# Storage Account Names (must be globally unique, 3-24 lowercase alphanumeric)
variable "preprocess_storage_name" {
  description = "Pre-process storage account name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.preprocess_storage_name))
    error_message = "Storage name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "postprocess_storage_name" {
  description = "Post-process storage account name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.postprocess_storage_name))
    error_message = "Storage name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "function_storage_name" {
  description = "Function app storage account name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.function_storage_name))
    error_message = "Storage name must be 3-24 lowercase alphanumeric characters."
  }
}

# Key Vault Name (must be globally unique, 3-24 alphanumeric and hyphens)
variable "keyvault_name" {
  description = "Key Vault name"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,24}$", var.keyvault_name))
    error_message = "Key Vault name must be 3-24 alphanumeric and hyphens."
  }
}

# Function App Name (must be globally unique)
variable "function_app_name" {
  description = "Function App name"
  type        = string
}

# User Principal Names (EntraID)
variable "user_jess_upn" {
  description = "Jess Admin user principal name (email)"
  type        = string
}

variable "user_jeff_upn" {
  description = "Jeff Developer user principal name (email)"
  type        = string
}

variable "user_bob_upn" {
  description = "Bob Reader user principal name (email)"
  type        = string
}

variable "user_raj_upn" {
  description = "Raj Client user principal name (email)"
  type        = string
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "SQL-Server-Monitoring"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Owner       = "Infrastructure-Team"
  }
}
