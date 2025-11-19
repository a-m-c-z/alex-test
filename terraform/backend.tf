# Terraform backend, including state file blob storage
terraform {
  required_version = ">= 1.5.0"
  backend "azurerm" {
    resource_group_name  = "REPLACE"
    storage_account_name = "REPLACE"
    container_name       = "REPLACE"
    key                  = "REPLACE.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}