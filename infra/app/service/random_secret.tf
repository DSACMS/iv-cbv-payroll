resource "random_password" "rails_secret_key_base" {
  length           = 64
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "rails_secret_key_base" {
  name  = "/service/${local.service_config.service_name}/rails-secret-key-base"
  type  = "SecureString"
  value = random_password.rails_secret_key_base.result
}