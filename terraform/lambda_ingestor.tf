#####################################################
# LAMBDA INGESTOR FUNCTION
#####################################################

resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for IoT ingestor Lambda"
  vpc_id      = data.aws_vpc.default.id

  # Ingress: Allow HTTPS from inside VPC for SSM VPC Endpoint
  ingress {
    description = "Allow HTTPS from VPC for VPC Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  # Egress: Allow all outbound (to EC2 PgBouncer on 6432 & SSM Endpoint on 443)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/dist/ingestor.zip"

  source_dir = "${path.module}/src"
}

resource "aws_lambda_function" "iot_ingestor" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "${var.project_name}-${var.environment}-ingestor"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 10

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST             = aws_instance.timescaledb.private_ip
      DB_PORT             = "6432" # Points to PgBouncer
      DB_NAME             = "iot_telemetry"
      DB_USER             = "app_user" # Non-superuser account
      SSM_PASS_PARAM_NAME = aws_ssm_parameter.db_password.name
    }
  }
}

# Grant Lambda permission to read the DB password parameter from SSM
resource "aws_iam_role_policy" "lambda_ssm_policy" {
  name = "${var.project_name}-${var.environment}-lambda-ssm-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = aws_ssm_parameter.db_password.arn
    }]
  })
}

# VPC Interface Endpoint for SSM (so Lambda in VPC can resolve & reach Parameter Store)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
}