# Zips everything in ../lambda and writes to ../build/ingest.zip
data "archive_file" "ingest_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/../build/ingest.zip"
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project}-ingest"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.ingest_zip.output_path
  source_code_hash = data.archive_file.ingest_zip.output_base64sha256
  handler          = "ingest_handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      RAW_BUCKET_NAME  = aws_s3_bucket.raw.bucket
      DDB_TABLE_NAME   = aws_dynamodb_table.bus_alerts.name
      METRIC_NAMESPACE = var.metric_namespace
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "ingest" {
  function_name                = aws_lambda_function.ingest.function_name
  maximum_retry_attempts       = 2
  maximum_event_age_in_seconds = 3600
}
