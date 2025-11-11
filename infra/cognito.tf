resource "aws_cognito_user_pool" "bus_pool" {
  name = "${var.project}-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "bus_client" {
  name         = "${var.project}-app-client"
  user_pool_id = aws_cognito_user_pool.bus_pool.id

  # no client secret for public/mobile/CLI flows
  generate_secret = false

  # allow username/password auth + refresh
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]
}
