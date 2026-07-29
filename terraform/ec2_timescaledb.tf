#####################################################
# HARDENED EC2 INSTANCE WITH IAM, EBS, DLM, AND PGBOUNCER
#####################################################

data "aws_vpc"  "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# IAM ROLE & PROFILES
resource "aws_iam_role" "timescaledb" {
  name = "${var.project_name}-${var.environment}-timescaledb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.timescaledb.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.timescaledb.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "timescaledb_inline" {
  name = "${var.project_name}-${var.environment}-timescaledb-inline"
  role   = aws_iam_role.timescaledb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "ReadDbPassword"
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = aws_ssm_parameter.db_password.arn
      },
      {
        Sid = "WriteBackups"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${module.backup_bucket.s3_bucket_arn}/timescaledb-backups/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "timescaledb" {
  name = "${var.project_name}-${var.environment}-timescaledb-profile"
  role = aws_iam_role.timescaledb.name
}

# Security Groups
resource "aws_security_group" "timescaledb_sg" {
  name = "${var.project_name}-${var.environment}-timescaledb-sg"
  description = "Allows ingress from Lambda SG to PgBouncer port only"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "PgBouncer traffic from Lambda"
    from_port = 6432
    to_port = 6432
    protocol = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-timescaledb-sg"
    Environment = var.environment
  }
}

# EBS volume & attachment
resource "aws_ebs_volume" "timescaledb_data" {
  availability_zone = aws_instance.timescaledb.availability_zone
  size = 20
  type = "gp3"
  encrypted = true

  tags = {
    Name = "${var.project_name}-${var.environment}-timescaledb-data"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "timescaledb_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.timescaledb_data.id
  instance_id = aws_instance.timescaledb.id
  stop_instance_before_detaching = true
}

# DataLifecycleManager Snapshot Policy
resource "aws_iam_role" "dlm_lifecycle" {
  name = "${var.project_name}-${var.environment}-dlm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dlm_lifecycle" {
  role       = aws_iam_role.dlm_lifecycle.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "timescaledb_snapshots" {
  description        = "Daily snapshots of TimescaleDB data volume"
  execution_role_arn = aws_iam_role.dlm_lifecycle.arn
  state = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Name = "${var.project_name}-${var.environment}-timescaledb-data"
    }

    schedule {
      name = "daily-snapshot"

      create_rule {
        interval = 24
        interval_unit = "HOURS"
        times = ["03:00"]
      }

      retain_rule {
        count = 7
      }

      copy_tags = true
    }
  }
}

# EC2 Instance
resource "aws_instance" "timescaledb" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids = [aws_security_group.timescaledb_sg.id]
  iam_instance_profile = aws_iam_instance_profile.timescaledb.name
  associate_public_ip_address = true
  disable_api_termination = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region = var.aws_region
    ssm_param_name = aws_ssm_parameter.db_password.name
    backup_bucket = module.backup_bucket.s3_bucket_id
    project_name = var.project_name
    environment = var.environment
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-timescaledb"
    Environment = var.environment
  }
}