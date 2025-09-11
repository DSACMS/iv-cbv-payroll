resource "aws_s3_bucket" "storage" {
  bucket = var.name

  # Use a separate line to support automated terraform destroy commands
  force_destroy = var.is_temporary

  # checkov:skip=CKV_AWS_144:Cross region replication not required by default
  # checkov:skip=CKV2_AWS_62:S3 bucket does not need notifications enabled
  # checkov:skip=CKV_AWS_21:Bucket versioning is not needed
}
