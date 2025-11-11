variable "project" {
  type    = string
  default = "bus-alerts"
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "raw_bucket_name" {
  type    = string
  default = "bus-alerts-raw-amar-ny-12345"
}
variable "ddb_table_name" {
  type    = string
  default = "bus-alerts"
}
variable "metric_namespace" {
  type    = string
  default = "BusAlerts"
}

variable "alerts_email" {
  type    = string
  default = "YOUR_EMAIL@example.com" # change me or leave empty to skip email subscription
}

variable "log_retention_days" {
  type    = number
  default = 14
}
