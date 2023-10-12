variable "app" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ec2_launch_template_id" {
  type = string
}

variable "access_logs_enabled" {
  type = bool
}

variable "access_logs_bucket" {
  type = string
}

variable "access_logs_prefix" {
  type = string
}
