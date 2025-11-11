
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project}-ingest-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions          = { FunctionName = aws_lambda_function.ingest.function_name }
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration_p95" {
  alarm_name          = "${var.project}-ingest-duration-p95"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p95"
  threshold           = 4000
  dimensions          = { FunctionName = aws_lambda_function.ingest.function_name }
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "high_alert_spike" {
  alarm_name          = "${var.project}-high-alerts-spike"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HighPriorityAlerts"
  namespace           = var.metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
}

# Lambda function Errors alarm (built-in metric)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-ingest-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  dimensions          = { FunctionName = aws_lambda_function.ingest.function_name }
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.bus_alerts.arn]
}

# Custom metric burst alarm: HighPriorityAlerts >= 3 in 5 minutes
resource "aws_cloudwatch_metric_alarm" "high_alert_burst" {
  alarm_name          = "${var.project}-high-alerts-burst"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HighPriorityAlerts"
  namespace           = var.metric_namespace # "BusAlerts"
  period              = 300                  # 5 minutes
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.bus_alerts.arn]
}
