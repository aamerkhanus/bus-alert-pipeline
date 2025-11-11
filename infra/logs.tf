resource "aws_cloudwatch_log_group" "lambda_ingest" {
  name              = "/aws/lambda/${aws_lambda_function.ingest.function_name}"
  retention_in_days = var.log_retention_days
  # If the log group already exists from first invoke, keepers ensure Terraform can adopt it
  # Optional: depends_on = [aws_lambda_function.ingest]
}
