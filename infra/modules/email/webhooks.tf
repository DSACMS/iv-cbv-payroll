############################################################################################
## EMAIL EVENTS
##
## This file contains the resources necssary to send webhooks back to the
## application for delivery events. The architecture is:
##
##      [AWS SES]   -->  [AWS EventBridge]  --> [NewRelic]
##        * DELIVER        * default Bus          * AWSSESEvent (custom event)
##        * OPEN           * Rule
##        * CLICK          * Connection
##        * ...
##
##
############################################################################################
data "aws_caller_identity" "current" {}
data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}
data "aws_ssm_parameter" "newrelic_api_key" {
  name = var.newrelic_api_key_param_name
}


############################################################################################
## SES Configuration
############################################################################################
resource "aws_sesv2_configuration_set_event_destination" "email_notifications" {
  configuration_set_name = aws_ses_configuration_set.require_tls.name
  event_destination_name = "eventbridge-email-events"

  event_destination {
    matching_event_types = [
      "OPEN",
      "CLICK",
      "SEND",
      "BOUNCE",
      "COMPLAINT",
      "DELIVERY",
      "DELIVERY_DELAY",
      "REJECT"
    ]
    enabled = true

    event_bridge_destination {
      event_bus_arn = data.aws_cloudwatch_event_bus.default.arn
    }
  }
}

############################################################################################
## EventBridge Configuration
##
## (note: EventBridge was formerly known as "CloudWatch Events")
############################################################################################
resource "aws_cloudwatch_event_rule" "ses_events" {
  name        = "ForwardSESEventsToNewRelic"
  description = "Forward AWS SES events to NewRelic custom event (AWSSESEvent)"

  event_pattern = jsonencode({
    source = ["aws.ses"]
  })
}

resource "aws_iam_role" "ses_events_to_newrelic" {
  name               = "SESEventsToNewRelic"
  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {
          "Service": "events.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }]
    }
  EOF
}
resource "aws_iam_role_policy" "ses_events_to_newrelic" {
  name = "SESEventsToNewRelic"
  role = aws_iam_role.ses_events_to_newrelic.id

  policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": [
          "events:InvokeApiDestination"
        ],
        "Resource": [
          "${aws_cloudwatch_event_api_destination.newrelic.arn}"
        ]
      }]
    }
  EOF
}


resource "aws_cloudwatch_event_target" "ses_events" {
  arn      = aws_cloudwatch_event_api_destination.newrelic.arn
  rule     = aws_cloudwatch_event_rule.ses_events.name
  role_arn = aws_iam_role.ses_events_to_newrelic.arn

  input_transformer {
    input_paths = {
      event     = "$.detail.eventType",
      messageId = "$.detail.mail.messageId"
    }

    input_template = <<EOF
      {
        "eventType": "AWSSESEvent",
        "eventName": "<event>",
        "messageId": "<messageId>"
      }
    EOF
  }
}

resource "aws_cloudwatch_event_api_destination" "newrelic" {
  name                = "NewRelic"
  description         = "Send SES events to NewRelic"
  invocation_endpoint = "https://insights-collector.newrelic.com/v1/accounts/${var.newrelic_account_id}/events"
  http_method         = "POST"
  connection_arn      = aws_cloudwatch_event_connection.newrelic.arn
}

resource "aws_cloudwatch_event_connection" "newrelic" {
  name               = "NewRelic"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "Api-Key"
      value = data.aws_ssm_parameter.newrelic_api_key.value
    }
  }
}
