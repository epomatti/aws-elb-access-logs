resource "aws_key_pair" "elb_access_logs" {
  key_name   = "elb-access-logs-keypair-${var.app}"
  public_key = file("${path.module}/../../keys/temp_key.pub")
}

resource "aws_iam_instance_profile" "default" {
  name = "elb-access-logs-profile-${var.app}"
  role = aws_iam_role.main.id
}

resource "aws_launch_template" "main" {
  name          = "launchtemplate-${var.app}"
  image_id      = var.image_id
  user_data     = filebase64("${path.module}/userdata.sh")
  instance_type = var.instance_type
  key_name      = aws_key_pair.elb_access_logs.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.default.arn
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring {
    enabled = false
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 20
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.elb.id]
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "elb-ec2-instance"
    }
  }
}

resource "aws_iam_role" "main" {
  name = "${var.app}-ec2-role"

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

resource "aws_iam_role_policy_attachment" "ssm-managed-instance-core" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  vpc_cidr_blocks = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group" "elb" {
  name   = "ec2-sg-${var.app}"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "inbound_http" {
  description       = "HTTP Inbound"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = local.vpc_cidr_blocks
  security_group_id = aws_security_group.elb.id
}

resource "aws_security_group_rule" "outbound_http" {
  description       = "HTTP Outbound"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb.id
}

resource "aws_security_group_rule" "outbound_https" {
  description       = "HTTPS Outbound"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb.id
}
