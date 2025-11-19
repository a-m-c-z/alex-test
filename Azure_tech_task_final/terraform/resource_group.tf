# Common tags for all resources

locals {
  common_tags = {
    Environment = "Production"
    Purpose     = "VM-SQL-Tracking"
    ManagedBy   = "Terraform"
  }
}
