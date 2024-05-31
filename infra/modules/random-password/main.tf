############################################################################################
## A module to generate a random password
############################################################################################

resource "random_password" "random_password" {
  length      = var.length
  special     = true
  min_special = 6
  # Remove '@' sign from allowed characters since only printable ASCII characters besides '/', '@', '"', ' ' may be used.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "random_password" {
  name  = var.ssm_param_name
  type  = "SecureString"
  value = random_password.random_password.result
}
