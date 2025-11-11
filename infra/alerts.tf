resource "aws_sns_topic" "bus_alerts" {
  name = "${var.project}-alerts"
}

# Optional email subscription – you must confirm from your inbox
resource "aws_sns_topic_subscription" "email" {
  count     = var.alerts_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.bus_alerts.arn
  protocol  = "email"
  endpoint  = var.alerts_email
}
