output "queue_urls" {
  value = merge(
    { for k, q in aws_sqs_queue.dicit_queues : k => q.url },
    { "dlq" = aws_sqs_queue.dlq.url }
  )
}

output "queue_arns" {
  value = merge(
    { for k, q in aws_sqs_queue.dicit_queues : k => q.arn },
    { "dlq" = aws_sqs_queue.dlq.arn }
  )
}
