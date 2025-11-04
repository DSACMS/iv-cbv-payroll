locals {
  resolved_names = [for n in var.queue_names : "${n}"]
  dlq_resolved   = var.dlq_name
}

resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_resolved
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  lifecycle { prevent_destroy = true }
}

resource "aws_sqs_queue" "dicit_queues" {
  for_each = toset(local.resolved_names)

  name                       = each.key
  visibility_timeout_seconds = var.visibility_timeout_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  delay_seconds              = 0
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = 262144
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}
