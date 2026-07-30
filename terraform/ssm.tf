#####################################################
# SSM - SECRETS MANAGEMENT
#####################################################

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/${var.environment}/timescaledb/app_password"
  type        = "SecureString"
  value       = random_password.db_password.result
  description = "Database user password for TimescaleDB application connections"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
