#####################################################
# QUERY LAMBDA FUNCTION - Reads TimescaleDB
#####################################################

# IAM Role for Query Lambda
resource "aws_iam_role" "query_lambda_role" {
  name = "${var.project_name}-${var.environment}-query-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach AWS VPC Execution Role & SSM Read Policy
resource "aws_iam_role_policy_attachment" "query_lambda_vpc_attach" {
  role       = aws_iam_role.query_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "query_lambda_ssm_policy" {
  name = "SSMParameterAccess"
  role = aws_iam_role.query_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["ssm:GetParameter"]
      Effect   = "Allow"
      Resource = [aws_ssm_parameter.db_password.arn]
    }]
  })
}

# Zip deployment package
data "archive_file" "query_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/query_lambda.zip"
}

# Query Lambda Function Definition
resource "aws_lambda_function" "query_telemetry" {
  filename         = data.archive_file.query_lambda_zip.output_path
  source_code_hash = data.archive_file.query_lambda_zip.output_base64sha256
  function_name    = "${var.project_name}-${var.environment}-query"
  role             = aws_iam_role.query_lambda_role.arn
  handler          = "query.handler"
  runtime          = "nodejs24.x"
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST        = aws_instance.timescaledb.private_ip
      DB_PORT        = "6432" # PgBouncer Port
      DB_NAME        = "iot_telemetry"
      DB_USER        = "app_user"
      SSM_PARAM_NAME = aws_ssm_parameter.db_password.name
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

