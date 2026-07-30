output "s3_bucket_name" {
  value = module.terraform_state_bucket.s3_bucket_id
  description = "copy this value into backend provider"
}

# AWS IOT CORE ENDPOINT & CERTIFICATES
output "iot_mqtt_endpoint" {
  value = data.aws_iot_endpoint.mqtt_endpoint.endpoint_address
  description = "The ATS MQTT host endpoint for virtual devices to connect"
}

output "device_certificate_pem" {
  value = aws_iot_certificate.device_cert.certificate_pem
  sensitive = true
  description = "Public certificate PEM for device mTLS authentication"
}

output "device_private_key" {
  value = aws_iot_certificate.device_cert.private_key
  sensitive = true
  description = "Private key for device mTLS authentication"
}

# Timescaledb and EC2 database endpoints
output "timescaledb_instance_id" {
  value = aws_instance.timescaledb.id
  description = "Connect using: aws ssm start-session --target <instance_id>"
}

output "timescaledb_private_ip" {
  value = aws_instance.timescaledb.private_ip
  description = "Private IP endpoint accessed by Lambda"
}

# Backup & Ingestion resources
output "backup_s3_bucket" {
  value = module.backup_bucket.s3_bucket_id
  description = "S3 bucket storing logical dumps"
}

output "lambda_ingestor_function_name" {
  value = aws_lambda_function.iot_ingestor.function_name
  description = "Name of the Lambda function handling MQTT ingestion into PgBouncer"
}


#####################################
## Cognito outputs
#####################################

# For Frontend integration
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
  description = "ID of the Cognito User Pool"
}

output "cognito_app_client_id" {
  value = aws_cognito_user_pool_client.user_pool_client.id
  description = "ID of the Cognito App Client"
}

#####################################
## API Gateway endpoint output
#####################################
output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
  description = "Base URL for the HTTP API Gateway"
}
