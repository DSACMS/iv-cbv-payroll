variable "queue_names" { type = set(string) }
variable "dlq_name" { type = string }
variable "visibility_timeout_seconds" { type = number }
variable "receive_wait_time_seconds" { type = number }
variable "message_retention_seconds" { type = number }
variable "max_receive_count" { type = number }
