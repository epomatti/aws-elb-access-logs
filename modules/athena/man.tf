resource "aws_athena_workgroup" "default" {
  name          = "elb-access-logs"
  state         = "ENABLED"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false

    result_configuration {
      output_location = "s3://${aws_s3_bucket.default.bucket}/output/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.default]
}

resource "random_string" "bucket" {
  length  = 5
  special = false
  upper   = false
  numeric = false
}

resource "aws_s3_bucket" "default" {
  bucket = "bucket-athenaresults-${random_string.bucket.result}"

  # For development purposes
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.default.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# FIXME: Too much permissions
resource "aws_s3_bucket_policy" "default" {
  bucket = aws_s3_bucket.default.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "AthenaPermissions",
    "Statement" : [
      {
        "Sid" : "1",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.account_id}:user/${var.principal}"
        },
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.default.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.default.bucket}/*",
        ]
      }
    ]
  })
}
