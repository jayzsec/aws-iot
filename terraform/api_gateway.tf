#####################################################
# API GATEWAY V2 - HTTP API & Cognito JWT Authorizer
#####################################################

# HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
    max_age       = 300
  }
}

# Stage - $default with auto-deploy
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Cognito JWT Authorizer
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.http_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "CognitoAuthorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.user_pool_client.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.user_pool.id}"
  }
}

# API Gateway -> Lambda Integration
resource "aws_apigatewayv2_integration" "query_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.query_telemetry.invoke_arn
  payload_format_version = "2.0"
}

# Route: GET /telemetry - Protected by Cognito
resource "aws_apigatewayv2_route" "get_telemetry_route" {
  api_id             = aws_apigatewayv2_api.http_api.id
  route_key          = "GET /telemetry"
  target             = "integrations/${aws_apigatewayv2_integration.query_integration.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Grant API Gateway permission to invoke Query Lambda
resource "aws_lambda_permission" "allow_api_gw_to_query_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_telemetry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
