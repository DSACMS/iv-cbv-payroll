resource "aws_iam_policy" "sqs_access" {
  name_prefix = "sqs_access_"
  description = "Allows access to SQS"
  policy = templatefile(
    "${path.module}/policies/sqs_policy.json", {}
  )
}

data "aws_iam_policy_document" "sqs_manager_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sqs_manager_role" {
  name_prefix        = "sqs-manager-role-"
  assume_role_policy = data.aws_iam_policy_document.sqs_manager_assume_role.json
}

resource "aws_iam_role_policy_attachment" "task_attach_sqs" {
  role       = aws_iam_role.sqs_manager_role.name
  policy_arn = aws_iam_policy.sqs_access.arn
}
