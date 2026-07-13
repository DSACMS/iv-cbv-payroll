resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  # checkov:skip=CKV_AWS_300:Abort period is set on the AbortIncompleteUpload rule; checkov miscounts when a second (dynamic) rule is present

  rule {
    id     = "AbortIncompleteUpload"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.expiration_days == null ? [] : [var.expiration_days]
    content {
      id     = "ExpireObjects"
      status = "Enabled"

      filter {}

      expiration {
        days = rule.value
      }
    }
  }
}
