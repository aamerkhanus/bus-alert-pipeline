output "lambda_name" {
  value = aws_lambda_function.ingest.function_name
}

output "raw_bucket" {
  value = aws_s3_bucket.raw.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.bus_alerts.name
}

output "api_url" { value = "${aws_apigatewayv2_api.bus_api.api_endpoint}/prod/bus-event" }
output "cognito_pool_id" { value = aws_cognito_user_pool.bus_pool.id }
output "cognito_client_id" { value = aws_cognito_user_pool_client.bus_client.id }

