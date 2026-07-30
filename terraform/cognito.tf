#################################################
# AWS COGNITO - User Pool & Authentication Client
#################################################

# Cognito User Pool
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.project_name}-${var.environment}-user-pool"

  # user sign-in attributes
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]

  # password strength policy
  password_policy {
    minimum_length = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers = true
    require_symbols = false
  }

  # attribute schema
  schema {
    attribute_data_type = "String"
    name                = "email"
    required = true
    mutable = true
  }

  tags = {
    Environment = var.environment
    ManagedBy = "Terraform"
  }
}

# Cognito User Pool Client - Used by Web or Mobile Clients
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "${var.project_name}-${var.environment}-app-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  # Authentication flows allowed
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Set false for SPA or Client-side JS apps
  generate_secret = false
}
