#####################################################
# LAMBDA INGESTOR FUNCTION
#####################################################

resource "aws_security_group" "lambda_sg" {
  name = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for IoT ingestor Lambda"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "lambda_dummy" {
  type        = "zip"
  output_path = "${path.module}/lambda_dummy.zip"

  source {
    content  = "exports.handler = async (event) => { console.log(JSON.stringify(event)); return { statusCode: 200 }; };"
    filename = "index.js"
  }
}

resource "aws_lambda_function" "iot_ingestor" {
  filename = data.archive_file.lambda_dummy.output_path
  function_name = "${var.project_name}-${var.environment}-ingestor"
  role          = aws_iam_role.lambda_exec_role.arn
  handler = "index.handler"
  runtime = "nodejs20.x"

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      DB_HOST = aws_instance.timescaledb.private_ip
      DB_PORT = "6432" # Points to PgBouncer
      DB_NAME = "iot_telemetry"
      DB_USER = "app_user" # Non-superuser account
      SSM_PASS_PARAM_NAME = aws_ssm_parameter.db_password.name
    }
  }
}