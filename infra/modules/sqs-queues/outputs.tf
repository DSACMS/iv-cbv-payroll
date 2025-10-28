output "queue_urls" { value = { for k, q in aws_sqs_queue.dicit_queues : k => q.url } }
output "queue_arns" { value = { for k, q in aws_sqs_queue.dicit_queues : k => q.arn } }
output "dlq_url" { value = aws_sqs_queue.dlq.url }
output "dlq_arn" { value = aws_sqs_queue.dlq.arn }
