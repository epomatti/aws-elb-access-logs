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

resource "aws_key_pair" "elb_access_logs" {
  key_name   = "elb-access-logs"
  public_key = file("${path.module}/id_rsa.pub")
}

resource "aws_iam_instance_profile" "base" {
  name = "elb-access-logs-profile"
  role = aws_iam_role.main.id
}

resource "aws_launch_template" "main" {
  name          = "launchtemplate-${var.app}"
  user_data     = filebase64("${path.module}/userdata.sh")
  image_id      = var.image_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.elb_access_logs.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.base.arn
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
    subnet_id                   = aws_subnet.public1.id
  }
}
