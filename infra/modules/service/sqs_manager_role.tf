resource "aws_iam_policy" "sqs_access" {
  name_prefix = "sqs_access_"
  description = "Allows access to SQS queues"
  policy      = data.aws_iam_policy_document.sqs_manager.json
}

data "aws_iam_policy_document" "sqs_manager" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
    ]

    resources = values(var.queue_arns)
  }
}
