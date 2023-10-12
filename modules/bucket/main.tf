resource "random_string" "bucket" {
  length  = 5
  special = false
  lower   = false
}

resource "aws_s3_bucket" "main" {
  bucket = "bucket-${var.app}-${random_string.bucket.result}"

  # For development purposes
  force_destroy = true
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

resource "aws_s3_bucket_policy" "elb_access_logs" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.elb_access_logs.json
}

data "aws_iam_policy_document" "elb_access_logs" {

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.main.bucket}/${var.app}/AWSLogs/*"]
    principals {
      identifiers = ["arn:aws:iam::${var.elb_account_id}:root"]
      type        = "AWS"
    }
  }
}
