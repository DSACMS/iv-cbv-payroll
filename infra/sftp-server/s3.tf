
resource "random_string" "s3_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  sftp_bucket_full_name = "${var.storage_bucket_name_prefix}${random_string.s3_bucket_suffix.result}"
}

resource "aws_s3_bucket" "sftp_s3_bucket" {
  bucket = local.sftp_bucket_full_name
}

resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.sftp_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.sftp_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}
