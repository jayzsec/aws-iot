#####################################################
# S3 BUCKET FOR LOGICAL PG_DUMP BACKUPS
#####################################################

module "backup_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.15.1"

  bucket                   = "${var.project_name}-${var.environment}-db-backups"
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  force_destroy            = false

  versioning = {
    enabled = true
  }
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
