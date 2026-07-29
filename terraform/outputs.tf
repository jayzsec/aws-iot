output "s3_bucket_name" {
  value = module.terraform_state_bucket.s3_bucket_id
  description = "copy this value into backend provider"
}

output "timescaledb_instance_id" {
  value = aws_instance.timescaledb.id
  description = "Connect using: aws ssm start-session --target <instance_id>"
}

output "timescaledb_private_ip" {
  value = aws_instance.timescaledb.private_ip
  description = "Private IP endpoint accessed by Lambda"
}

output "backup_s3_bucket" {
  value = module.backup_bucket.s3_bucket_id
  description = "S3 bucket storing logical dumps"
}
