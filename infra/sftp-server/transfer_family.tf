
resource "aws_transfer_server" "this" {
  endpoint_type               = "VPC"
  logging_role                = aws_iam_role.logging_role.arn
  identity_provider_type      = "AWS_LAMBDA"
  function                    = aws_lambda_function.sftp_auth_lambda_function.arn
  domain                      = "S3"
  sftp_authentication_methods = "PASSWORD"
  protocols                   = ["SFTP"]
  structured_log_destinations = ["${aws_cloudwatch_log_group.sftp.arn}:*"]
  security_policy_name        = "TransferSecurityPolicy-2024-01"

  endpoint_details {
    address_allocation_ids = aws_eip.static_sftp_ip[*].id
    vpc_id                 = aws_vpc.this.id
    subnet_ids             = aws_subnet.public[*].id
    security_group_ids     = [aws_security_group.sftp_sg.id]
  }
}
resource "aws_kms_key" "sftp_logs_kms_key" {
  description             = "Customer Managed KMS key to encrypt SFTP Auth Lambda Function Environment Variables"
  deletion_window_in_days = 10
  enable_key_rotation     = true # Enable automatic key rotation
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowAccountRootFullAccess",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogsUseOfTheKey",
        Effect    = "Allow",
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })
}
resource "aws_cloudwatch_log_group" "sftp" {
  name_prefix       = "sftp_"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.sftp_logs_kms_key.arn
}


resource "aws_iam_role_policy" "sftp_s3_policy" {
  name = "sftp-s3-access-policy-${local.sftp_bucket_full_name}"
  role = aws_iam_role.sftp_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Sid" : "ListBucketItems",
      "Effect" : "Allow",
      "Action" : [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource" : "arn:aws:s3:::${local.sftp_bucket_full_name}"
      },
      {
        "Sid" : "BucketPermissions",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObjectAcl",
          "s3:GetObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:GetObjectVersion",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ],
        "Resource" : "arn:aws:s3:::${local.sftp_bucket_full_name}/*"
    }]
  })
}

# Allow the Transfer Family role to use the KMS key for S3 SSE-KMS
resource "aws_iam_role_policy" "sftp_s3_kms_policy" {
  name = "sftp-s3-kms-policy-${local.sftp_bucket_full_name}"
  role = aws_iam_role.sftp_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowUseOfKmsKeyForS3",
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.sftp_ssm_kms_key.arn
      }
    ]
  })
}

resource "aws_iam_role" "sftp_role" {
  name               = "sftp-transfer-s3-access-${local.sftp_bucket_full_name}"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "transfer.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

