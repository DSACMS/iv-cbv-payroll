variable "domain" {
  type        = string
  description = "The name of the desired SES domain"
}

variable "hosted_zone_domain" {
  type        = string
  description = "The name of an existing Route53 hosted zone domain"
}

variable "newrelic_account_id" {
  type        = string
  description = "ID of the NewRelic account to receive SES events"
}

variable "newrelic_api_key_param_name" {
  type        = string
  description = "SSM Param Name of a AWS Parameter that has the NewRelic API key"
}

variable "verified_emails" {
  type        = list(string)
  description = "A list of verified emails to manage"
  default     = []
}
