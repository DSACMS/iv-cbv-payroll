variable "hosted_zone_domain" {
  type        = string
  description = "The name of an existing Route53 hosted zone domain"
}

variable "domain" {
  type        = string
  description = "The name of the desired SES domain"
}

variable "verified_emails" {
  type        = list(string)
  description = "A list of verified emails to manage"
  default     = []
}
