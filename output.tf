output "lb_dns_name" {
  value = module.elb.lb_dns_name
}

output "athena_s3_datasource_location" {
  value = "s3://${module.bucket.bucket}/${local.access_logs_prefix}/AWSLogs/${local.account_id}/elasticloadbalancing/${var.aws_region}/"
}
