resource "aws_lb" "main" {
  name               = "alb-${var.app}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = var.subnet_ids

  access_logs {
    enabled = var.access_logs_enabled
    prefix  = var.access_logs_prefix
    bucket  = var.access_logs_bucket
  }
}

resource "aws_lb_target_group" "main" {
  name     = "tg-elb-${var.app}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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
  name                = "asg-${var.app}"
  target_group_arns   = [aws_lb_target_group.main.arn]
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = var.ec2_launch_template_id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

locals {
  vpc_cidr_blocks = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group" "elb" {
  name   = "elb-sg-${var.app}"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "inbound_http" {
  description       = "HTTP Inbound"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elb.id
}

resource "aws_security_group_rule" "outbound_http" {
  description       = "HTTP Outbound"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = local.vpc_cidr_blocks
  security_group_id = aws_security_group.elb.id
}
