variable "length" {
  type        = number
  description = "The desired password length"
  default     = 48
}

variable "ssm_param_name" {
  type        = string
  description = "The name of a Parameter Store SecureString to save the random password as"
}
