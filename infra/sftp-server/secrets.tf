
resource "aws_secretsmanager_secret" "sftp_secret" {
    name = "aws/transfer/${aws_transfer_server.this.id}/${var.transer_familiy_default_user}"
    recovery_window_in_days  = 0
}

resource "random_password" "this" {
    length           = 64
    special          = true
    override_special = "_%@"
}

resource "aws_secretsmanager_secret_version" "sftp_secret_version" {
    secret_id = aws_secretsmanager_secret.sftp_secret.id
    secret_string = <<EOF
    {
        "password": "${random_password.this.result}",
        "role": "${aws_iam_role.sftp_role.arn}",
        "home_dir": "/${local.sftp_bucket_full_name}"
    }
    EOF
}
