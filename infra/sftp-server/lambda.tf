
locals {
  auth_lambda_function_name = "sftp_test_server_auth"
}

resource "aws_sns_topic" "sftp_auth_lambda_dlq" {
  name              = "sftp-auth-lambda-function-dead-letter-queue"
  kms_master_key_id = "alias/aws/sns"
}

data "archive_file" "auth_lambda_function_archive" {
  type = "zip"

  source_dir  = "${path.module}/functions/auth_lambda"
  output_path = "${path.module}/functions/auth_lambda.zip"
}

resource "aws_lambda_function" "sftp_auth_lambda_function" {
  filename         = data.archive_file.auth_lambda_function_archive.output_path
  function_name    = local.auth_lambda_function_name
  role             = aws_iam_role.sftp_lambda_role.arn
  handler          = "auth_lambda.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  layers           = ["arn:aws:lambda:us-east-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python38-arm64:4"]
  source_code_hash = data.archive_file.auth_lambda_function_archive.output_base64sha256
  kms_key_arn      = aws_kms_key.sftp_ssm_kms_key.arn

  reserved_concurrent_executions = 10
  tracing_config {
    mode = "Active"
  }
  #checkov:skip=CKV_AWS_117:Ensure that AWS Lambda function is configured inside a VPC

  dead_letter_config {
    target_arn = aws_sns_topic.sftp_auth_lambda_dlq.arn
  }

  environment {
    variables = {
      SecretsManagerRegion = var.aws_region
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.transfer_sftp_sns_policy_attachment,
    aws_iam_role_policy_attachment.transfer_sftp_policy_attachment,
    aws_iam_role_policy_attachment.transfer_sftp_kms_policy_attachment
  ]
}

resource "aws_iam_role" "sftp_lambda_role" {
  name = "sftp-lambda-auth-role-${local.auth_lambda_function_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "sftp_auth_lambda_policy" {
  name_prefix = "sftp_lambda_execution_policy_"
  description = "sftp_lambda_execution_policy"
  policy = templatefile(
    "${path.module}/policies/lambda_auth_role_policy.json",
    {
      region                    = var.aws_region,
      account_id                = data.aws_caller_identity.current.account_id,
      lambda_auth_function_name = local.auth_lambda_function_name
      transfer_server_id        = "*" # avoids a circular dependency between the policy, the lambda, and the transfer_server
    }
  )
}

resource "aws_iam_role_policy_attachment" "transfer_sftp_policy_attachment" {
  policy_arn = aws_iam_policy.sftp_auth_lambda_policy.arn
  role       = aws_iam_role.sftp_lambda_role.name
}

resource "aws_iam_policy" "sftp_auth_lambda_sns_publish_policy" {
  name_prefix = "sftp_lambda_sns_publish_"
  description = "Allow Lambda to publish to DLQ SNS topic"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.sftp_auth_lambda_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_sftp_sns_policy_attachment" {
  policy_arn = aws_iam_policy.sftp_auth_lambda_sns_publish_policy.arn
  role       = aws_iam_role.sftp_lambda_role.name
}

resource "aws_iam_policy" "sftp_auth_lambda_kms_policy" {
  name_prefix = "sftp_lambda_kms_access_"
  description = "Allow Lambda to use CMK for Secrets Manager and env var decryption"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.sftp_ssm_kms_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transfer_sftp_kms_policy_attachment" {
  policy_arn = aws_iam_policy.sftp_auth_lambda_kms_policy.arn
  role       = aws_iam_role.sftp_lambda_role.name
}

resource "aws_iam_role_policy" "logging_role_policy" {
  name = "sftp-logging-policy-${local.sftp_bucket_full_name}"
  role = aws_iam_role.logging_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowCloudwatchLogAccess"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/aws/transfer/*"
      }
    ]
  })
}

resource "aws_iam_role" "logging_role" {
  name               = "sftp-logging-role-${local.sftp_bucket_full_name}"
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


resource "aws_lambda_permission" "transfer_sftp_lambda_invoke" {
  statement_id  = "permit-invoke-by-sftp-${aws_transfer_server.this.id}"
  action        = "lambda:InvokeFunction"
  function_name = local.auth_lambda_function_name
  principal     = "transfer.amazonaws.com"
  source_arn    = aws_transfer_server.this.arn
}
