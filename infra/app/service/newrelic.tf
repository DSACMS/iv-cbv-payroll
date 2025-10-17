resource "aws_iam_role" "newrelic_metrics" {
  count = !local.is_temporary ? 1 : 0
  # checkov:skip=CKV_AWS_61:This policy principal needs to be broad to allow for monitoring all services.

  name = "newrelic-metrics-collector-${var.environment_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "754728514883" # NewRelic's AWS Account ID
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.environment_config.newrelic_config.account_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "newrelic_metrics" {
  count      = !local.is_temporary ? 1 : 0
  role       = aws_iam_role.newrelic_metrics[0].id
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
