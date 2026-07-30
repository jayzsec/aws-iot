######################################################
# CONTROL LAMBDA FUNCTION - Sends Commands to IoT Core
######################################################

# IAM Role for Control Lambda
resource "aws_iam_role" "control_lambda_role" {
  name = "${var.project_name}-${var.environment}-control-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach Basic Execution & VPC Access
resource "aws_iam_role_policy_attachment" "control_lambda_vpc_attach" {
  role       = aws_iam_role.control_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# IAM Policy: Grant iot:Publish to device control topics
resource "aws_iam_role_policy" "control_lambda_iot_policy" {
  name = "IoTPublishAccess"
  role   = aws_iam_role.control_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["iot:Publish"]
      Effect = "Allow"
      Resource = ["arn:aws:iot:${var.aws_region}:*:topic/telemetry/*/control"]
    }]
  })
}

# Control Lambda Function Definition
resource "aws_lambda_function" "control_telemetry" {
  filename = data.archive_file.query_lambda_zip.output_path
  source_code_hash = data.archive_file.query_lambda_zip.output_base64sha256
  function_name = "${var.project_name}-${var.environment}-control"
  role          = aws_iam_role.control_lambda_role.arn
  handler = "control.handler"
  runtime = "nodejs24.x"
  timeout = 10
  memory_size = 256

  environment {
    variables = {
      IOT_ENDPOINT = data.aws_iot_endpoint.mqtt_endpoint.endpoint_address
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy = "Terraform"
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "control_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.control_telemetry.invoke_arn
  payload_format_version = "2.0"
}

# Route: POST /devices/{device_id}/control - protected by Cognito
resource "aws_apigatewayv2_route" "post_control_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /devices/{device_id}/control"
  target = "integrations/${aws_apigatewayv2_integration.control_integration.id}"
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Permission: Allow API Gateway to invoke Control Lambda
resource "aws_lambda_permission" "allow_api_gw_to_control_lambda" {
  statement_id = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.control_telemetry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
