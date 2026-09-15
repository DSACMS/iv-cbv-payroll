
# Create SNS topic for all email and external incident management tools notifications

resource "aws_sns_topic" "this" {
  name = "${var.service_name}-monitoring"

  # checkov:skip=CKV_AWS_26:SNS encryption for alerts is unnecessary
}

# Create CloudWatch alarms for the service

resource "aws_cloudwatch_metric_alarm" "high_app_http_5xx_count" {
  alarm_name          = "${var.service_name}-high-app-5xx-count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "High HTTP service 5XX error count"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this.arn]
  ok_actions          = [aws_sns_topic.this.arn]

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "high_load_balancer_http_5xx_count" {
  alarm_name          = "${var.service_name}-high-load-balancer-5xx-count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "High HTTP ELB 5XX error count"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this.arn]
  ok_actions          = [aws_sns_topic.this.arn]

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "high_app_response_time" {
  alarm_name          = "${var.service_name}-high-app-response-time"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0.2
  alarm_description   = "High target latency alert"
  alarm_actions       = [aws_sns_topic.this.arn]
  ok_actions          = [aws_sns_topic.this.arn]

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
  }
}

# CloudWatch Log Metric Filter & Alarm for NSC/Hub API Failures
resource "aws_cloudwatch_log_metric_filter" "nsc_hub_failures" {
  count          = var.log_group_name != null ? 1 : 0
  name           = "${var.service_name}-nsc-hub-failures"
  pattern        = "\"[NSC/Hub Failure]\""
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "NscHubFailures"
    namespace     = "Custom/Service/${var.service_name}"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "nsc_hub_high_failure_rate" {
  count               = var.log_group_name != null ? 1 : 0
  alarm_name          = "${var.service_name}-nsc-hub-high-failure-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "NscHubFailures"
  namespace           = "Custom/Service/${var.service_name}"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "High NSC/Hub API failure count exceeded threshold over 5-minute window"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this.arn]
  ok_actions          = [aws_sns_topic.this.arn]
}

# CloudWatch Log Metric Filter & Alarm for NSC Client Certificate Expiration
resource "aws_cloudwatch_log_metric_filter" "nsc_cert_expiring" {
  count          = var.log_group_name != null ? 1 : 0
  name           = "${var.service_name}-nsc-cert-expiring"
  pattern        = "\"[NSC Client Cert EXPIRING SOON]\""
  log_group_name = var.log_group_name

  metric_transformation {
    name          = "NscCertExpiring"
    namespace     = "Custom/Service/${var.service_name}"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "nsc_client_cert_expiring" {
  count               = var.log_group_name != null ? 1 : 0
  alarm_name          = "${var.service_name}-nsc-client-cert-expiring"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "NscCertExpiring"
  namespace           = "Custom/Service/${var.service_name}"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "NSC client certificate is expiring soon or expired - renewal required"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this.arn]
  ok_actions          = [aws_sns_topic.this.arn]
}

#email integration

resource "aws_sns_topic_subscription" "email_integration" {
  for_each  = var.email_alerts_subscription_list
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}

#External incident management service integration

resource "aws_sns_topic_subscription" "incident_management_service_integration" {
  count                  = var.incident_management_service_integration_url != null ? 1 : 0
  endpoint               = var.incident_management_service_integration_url
  endpoint_auto_confirms = true
  protocol               = "https"
  topic_arn              = aws_sns_topic.this.arn
}
