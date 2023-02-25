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

resource "aws_security_group_rule" "all_traffic_inbound_https" {
  description       = "HTTPS Inbound"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb.id
}

resource "aws_security_group_rule" "all_traffic_outbound_https" {
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
