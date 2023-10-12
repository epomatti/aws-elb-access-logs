resource "random_string" "bucket" {
  length  = 5
  special = false
  upper   = false
  numeric = false
}

resource "aws_s3_bucket" "default" {
  bucket = "bucket-${var.app}-${random_string.bucket.result}"

  # For development purposes
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "default" {
  bucket = aws_s3_bucket.default.id

  versioning_configuration {
    status = "Enabled"
  }
}

# resource "aws_s3_bucket_logging" "main" {
#   bucket = aws_s3_bucket.main.id

#   target_bucket = aws_s3_bucket.main.id
#   target_prefix = "log/"
# }

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.default.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "elb_access_logs" {
  bucket = aws_s3_bucket.default.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "AllowELBAccessLogs",
    "Statement" : [
      {
        "Sid" : "1",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.elb_account_id}:root"
        },
        "Action" : "s3:PutObject",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.default.bucket}/${var.app}/AWSLogs/*",
        ]
      }
    ]
  })
}
