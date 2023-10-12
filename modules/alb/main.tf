resource "aws_lb" "main" {
  name               = "elb-${var.app}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  access_logs {
    enabled = true
    prefix  = var.app
    bucket  = var.access_log_bucket
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
  name = "asg-${var.app}"
  launch_template {
    id      = aws_launch_template.main.id
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

resource "aws_security_group_rule" "inbound_https" {
  description       = "HTTPS Inbound"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
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
