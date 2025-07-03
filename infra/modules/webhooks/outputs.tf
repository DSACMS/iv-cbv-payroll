output "webhook_registrar_role_arn" {
  description = "the ARN of the role that should be used for registering webhooks"
  value       = aws_iam_role.webhook_registrar.arn
} 