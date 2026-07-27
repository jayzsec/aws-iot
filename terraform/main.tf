terraform {
  required_version = ">= 1.15.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9"
    }
  }

  backend "s3" {
    bucket = "iot-fleet-platform-tfstate-c21ca50d"
    key = "dev/infrastructure.tfstate"
    region = "ap-southeast-2"
    encrypt = true
    use_lockfile = true
  }
}

provider "aws" {
  # Sydney
  region = "ap-southeast-2"
}

# variable
variable "project_name" {
  type = string
  default = "iot-fleet-platform"
  description = "Base name for resources"
}

variable "aws_region" {
  type = string
  default = "ap-southeast-2"
  description = "Default region for the project"
}

variable "environment" {
  type = string
  default = "dev"
  description = "Deployment environment - dev, staging, prod"
}

variable "timestream_memory_store_retention_hours" {
  type = number
  default = 24
  description = "Duration in hours to keep telemetry in Timestream in-memory store"
}

variable "timestream_magnetic_store_retention_days" {
  type = number
  default = 365
  description = "Duration in days to keep telemetry in Timestream magnetic disk store"
}

# random id
resource "random_id" "suffix" {
  byte_length = 4
}

module "terraform_state_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.15.1"

  # unique name of the bucket
  bucket = "${var.project_name}-tfstate-${random_id.suffix.hex}"

  # Best practice
  control_object_ownership = true
  object_ownership = "BucketOwnerEnforced"

  # safeguards
  # prevents accidental destroy
  force_destroy = false

  # enable versioning to keep history of terraform.tfstate
  versioning = {
    enabled = true
  }

  # default but for auditability - Encryption at rest
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # block public access - security
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

output "s3_bucket_name" {
  value = module.terraform_state_bucket.s3_bucket_id
  description = "copy this value into backend provider"
}

output "iot_mqtt_endpoint" {
  value = data.aws_iot_endpoint.mqtt_endpoint.endpoint_address
  description = "The ATS MQTT host endpoint for devices to connect to"
}

output "timestream_database_name" {
  value = aws_timestreamwrite_database.telemetry.database_name
  description = "Name of the Timestream Database"
}

output "timestream_table_name" {
  value = aws_timestreamwrite_table.telemetry.table_name
  description = "Name of the Timestream Table"
}

output "device_certificate_pem" {
  value = aws_iot_certificate.device_cert.certificate_pem
  sensitive = true
  description = "Public certificate PEM for the simulator device"
}

output "device_private_key" {
  value = aws_iot_certificate.device_cert.private_key
  sensitive = true
  description = "Private key for the simulator device"
}

# versioning lifecycle
# enforce tls/ssl
# delete protection state-file
# no access logging
# kms instead of aes256
