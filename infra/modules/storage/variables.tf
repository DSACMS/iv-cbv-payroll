variable "is_temporary" {
  description = "Whether the service is meant to be spun up temporarily (e.g. for automated infra tests). This is used to disable deletion protection."
  type        = bool
  default     = false
}

variable "name" {
  type        = string
  description = "Name of the AWS S3 bucket. Needs to be globally unique across all regions."
}

variable "expiration_days" {
  description = "Days after which objects are deleted (garbage collected). Null disables expiration. Matches DataRetentionService 7-day retention when set."
  type        = number
  default     = null
}
