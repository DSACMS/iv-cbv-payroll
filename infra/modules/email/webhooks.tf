data "aws_caller_identity" "current" {}

############################################################################################
## Create SNS topic to receive delivery success & failure events
############################################################################################
resource "aws_sns_topic" "email_notifications" {
  name              = "email-notifications"
  kms_master_key_id = aws_kms_key.email_notifications_encryption.id
}

data "aws_iam_policy_document" "email_notifications" {
  # See: https://docs.aws.amazon.com/ses/latest/dg/configure-sns-notifications.html
  statement {
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    actions = [
      "SNS:Publish",
    ]

    resources = [
      aws_sns_topic.email_notifications.arn
    ]

    effect = "Allow"

    condition {
      test     = "ArnEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_ses_configuration_set.require_tls.arn
      ]
    }
  }
}

resource "aws_sns_topic_policy" "email_notifications" {
  arn    = aws_sns_topic.email_notifications.arn
  policy = data.aws_iam_policy_document.email_notifications.json
}

data "aws_iam_policy_document" "email_notifications_encryption" {
  # Default key policy allowing maintenance of the key:
  # checkov:skip=CKV_AWS_111:These don't need constraints because of the account principal
  # checkov:skip=CKV_AWS_109:These don't need constraints because of the account principal
  statement {
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow access by SES:
  statement {
    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_kms_key" "email_notifications_encryption" {
  description         = "Encryption for Email Delivery Events"
  policy              = data.aws_iam_policy_document.email_notifications_encryption.json
  enable_key_rotation = true
}

resource "aws_sesv2_configuration_set_event_destination" "email_notifications" {
  configuration_set_name = aws_ses_configuration_set.require_tls.name
  event_destination_name = "sns-email-notifications"

  depends_on = [aws_sns_topic_policy.email_notifications, aws_kms_key.email_notifications_encryption]

  event_destination {
    matching_event_types = [
      "BOUNCE",
      "COMPLAINT",
      "DELIVERY",
      "DELIVERY_DELAY",
      "REJECT"
    ]
    enabled = true

    sns_destination {
      topic_arn = aws_sns_topic.email_notifications.arn
    }
  }
}

