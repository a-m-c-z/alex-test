# Password Rotation Configuration
# This rotates the excel password every 90 days automatically
# Note: Used AI to come up with approaches on how to integrate password rotation with Terraform CI/CD

# Time-based rotation trigger
resource "time_rotating" "password_rotation" {
  rotation_days = 90

  triggers = {
    # Force rotation on first apply if secret doesn't exist
    key_vault_id = azurerm_key_vault.main.id
  }
}

# Generate a new password when rotation period expires
resource "random_password" "report_password" {
  length           = 16
  special          = true
  min_special      = 2
  min_numeric      = 2
  min_upper        = 2
  min_lower        = 2
  override_special = "!@#$%^&*"

  keepers = {
    # This triggers password regeneration every 90 days
    rotation_time = time_rotating.password_rotation.id
  }
}

# Store password in Key Vault
resource "azurerm_key_vault_secret" "postprocess_password" {
  name         = "postprocess-secret"
  value        = random_password.report_password.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "password"

  # Optional: Set expiration date for compliance
  expiration_date = timeadd(timestamp(), "2160h") # 90 days from now

  # Tag with rotation info
  tags = merge(var.tags, {
    RotationSchedule = "90-days"
    LastRotated      = timestamp()
  })
}

# Output rotation information (for monitoring)
output "password_rotation_info" {
  description = "Password rotation metadata"
  value = {
    next_rotation_date  = time_rotating.password_rotation.rotation_rfc3339
    days_until_rotation = time_rotating.password_rotation.rotation_days
    secret_name         = azurerm_key_vault_secret.postprocess_password.name
  }
}
