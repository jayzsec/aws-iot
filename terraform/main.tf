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
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
  }

  backend "s3" {
    bucket       = "iot-fleet-platform-tfstate-c21ca50d"
    key          = "dev/infrastructure.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  # Sydney
  region = "ap-southeast-2"
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

# versioning lifecycle
# enforce tls/ssl
# delete protection state-file
# no access logging
# kms instead of aes256
