# HTTP API
resource "aws_apigatewayv2_api" "bus_api" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"
}

# Lambda proxy integration
resource "aws_apigatewayv2_integration" "ingest_integration" {
  api_id                 = aws_apigatewayv2_api.bus_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# JWT authorizer backed by Cognito
resource "aws_apigatewayv2_authorizer" "cognito_auth" {
  api_id           = aws_apigatewayv2_api.bus_api.id
  authorizer_type  = "JWT"
  name             = "${var.project}-cognito-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.bus_pool.id}"
    audience = [aws_cognito_user_pool_client.bus_client.id]
  }
}

# Route: POST /bus-event (secured by JWT)
resource "aws_apigatewayv2_route" "bus_event_route" {
  api_id    = aws_apigatewayv2_api.bus_api.id
  route_key = "POST /bus-event"
  target    = "integrations/${aws_apigatewayv2_integration.ingest_integration.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_auth.id
}

# Stage (prod)
resource "aws_apigatewayv2_stage" "prod_stage" {
  api_id      = aws_apigatewayv2_api.bus_api.id
  name        = "prod"
  auto_deploy = true
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowInvokeFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.bus_api.execution_arn}/*/*"
}
