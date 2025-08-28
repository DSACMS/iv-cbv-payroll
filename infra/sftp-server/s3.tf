resource "random_string" "s3_bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  sftp_bucket_full_name = "${var.storage_bucket_name_prefix}${data.aws_caller_identity.current.account_id}-${random_string.s3_bucket_suffix.result}"
}

module "storage" {
  source       = "../modules/storage"
  name         = local.sftp_bucket_full_name
  is_temporary = true
}

# Enable default SSE-KMS on the S3 bucket to ensure writes succeed in environments
# that enforce KMS encryption. We use the existing CMK used for SFTP secrets.
resource "aws_s3_bucket_server_side_encryption_configuration" "sftp_bucket_encryption" {
  bucket = local.sftp_bucket_full_name

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.sftp_ssm_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}