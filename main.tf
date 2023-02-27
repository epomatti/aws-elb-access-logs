terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  app                 = "sandbox"
  account_id          = data.aws_caller_identity.current.account_id
  availability_zone_1 = "${var.aws_region}a"
  availability_zone_2 = "${var.aws_region}b"
}

### VPC ###
resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  # Enable DNS hostnames 
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = local.availability_zone_1

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.availability_zone_2

  # Auto-assign public IPv4 address
  map_public_ip_on_launch = true
}

resource "aws_security_group" "elb" {
  name   = "elb-sg-${local.app}"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "all_traffic_inbound" {
  description       = "HTTPS Inbound"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb.id
}

resource "aws_security_group_rule" "all_traffic_outbound" {
  description       = "HTTPS Outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb.id
}


### S3 ###

resource "random_string" "bucket" {
  length    = 16
  min_lower = 16
  special   = false
}

resource "aws_s3_bucket" "main" {
  bucket = "bucket-${local.app}-${random_string.bucket.result}"

  # For development purposes
  force_destroy = true
}

resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "main" {
  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.main.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ELB Permissions
resource "aws_s3_bucket_policy" "elb_access_logs" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.elb_access_logs.json
}

data "aws_iam_policy_document" "elb_access_logs" {

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.main.bucket}/${local.app}/AWSLogs/*"]
    principals {
      identifiers = ["arn:aws:iam::${var.elb_account_id}:root"]
      type        = "AWS"
    }
  }
}

### ELB ###

resource "aws_lb" "main" {
  name               = "elb-${local.app}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  access_logs {
    enabled = true
    prefix  = local.app
    bucket  = aws_s3_bucket.main.bucket
  }

  depends_on = [
    aws_s3_bucket_policy.elb_access_logs
  ]
}

resource "aws_lb_target_group" "main" {
  name     = "tg-elb-${local.app}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled = true
    path    = "/"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_autoscaling_group" "default" {
  name = "asg-${local.app}"
  launch_template {
    id = aws_launch_template.main.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.public1.id]
  target_group_arns   = [aws_lb_target_group.main.arn]

  lifecycle {
    create_before_destroy = true
  }
}

### IAM Role ###

resource "aws_iam_role" "main" {
  name = "${local.app}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-core" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_launch_template" "main" {
  name          = "launchtemplate-${local.app}"
  user_data     = filebase64("${path.module}/config/userdata.sh")
  image_id      = "ami-0cc87e5027adcdca8"
  instance_type = var.instance_type

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 20
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.elb.id]
    # delete_on_termination       = true
    # subnet_id                   = aws_subnet.public1.id
  }

  # vpc_security_group_ids = [aws_security_group.elb.id]

}
