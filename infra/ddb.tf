resource "aws_dynamodb_table" "bus_alerts" {
  name         = var.ddb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Route_Number"
  range_key    = "Occurred_On"

  attribute {
    name = "Route_Number"
    type = "S"
  }

  attribute {
    name = "Occurred_On"
    type = "S"
  }
}
