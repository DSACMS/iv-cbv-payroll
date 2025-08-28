resource "random_password" "random_string" {
  length           = 64
  special          = true
  override_special = "_%@"
}

resource "aws_kms_key" "sftp_ssm_kms_key" {
  description             = "Customer Managed KMS key to encrypt SSM parameters for test SFTP server."
  deletion_window_in_days = 10
  enable_key_rotation     = true # Enable automatic key rotation
}

resource "aws_ssm_parameter" "sftp_test_user_password" {
  name        = "/sftp-server/sftp_test_user_password"
  description = "The password for the provisioned SFTP test user"
  type        = "SecureString"
  value       = random_password.random_string.result
  key_id      = aws_kms_key.sftp_ssm_kms_key.arn
}

resource "aws_secretsmanager_secret" "sftp_secret" {
  name                    = "aws/transfer/${aws_transfer_server.this.id}/${var.transer_familiy_default_user}"
  recovery_window_in_days = 0
  kms_key_id              = aws_kms_key.sftp_ssm_kms_key.arn
  # checkov:skip=CKV2_AWS_57: Ensure Secrets Manager secrets should have automatic rotation enabled
  # since this sftp server is short lived, there is no need for rotation.
}


resource "aws_secretsmanager_secret_version" "sftp_secret_version" {
  secret_id     = aws_secretsmanager_secret.sftp_secret.id
  secret_string = <<EOF
    {
        "password": "${aws_ssm_parameter.sftp_test_user_password.value}",
        "role": "${aws_iam_role.sftp_role.arn}",
        "home_dir": "/${local.sftp_bucket_full_name}"
    }
    EOF
}
