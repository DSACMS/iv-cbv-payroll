output "s3_bucket_name" {
  value = local.sftp_bucket_full_name
}

output "sftp_static_ip_list" {
  value = aws_eip.static_sftp_ip[*].public_ip
}

output "sftp_password" {
  value = nonsensitive(random_password.this.result)
}