output "random_password" {
  value     = random_password.random_password.result
  sensitive = true
}

output "ssm_arn" {
  value = aws_ssm_parameter.random_password.arn
}

output "ssm_name" {
  value = aws_ssm_parameter.random_password.name
}
