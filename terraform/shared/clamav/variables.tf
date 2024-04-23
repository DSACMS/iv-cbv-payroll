variable "cf_api_url" {
  type        = string
  description = "cloud.gov api url"
  default     = "https://api.fr.cloud.gov"
}

variable "cf_user" {
  type        = string
  description = "cloud.gov deployer account user"
}

variable "cf_password" {
  type        = string
  description = "secret; cloud.gov deployer account password"
  sensitive   = true
}

variable "cf_org_name" {
  type        = string
  description = "cloud.gov organization name"
}

variable "cf_space_name" {
  type        = string
  description = "cloud.gov space name (staging or prod)"
}

variable "env" {
  type        = string
  description = "deployment environment (staging, production)"
}

variable "clamav_image" {
  type        = string
  description = "Docker image to deploy the clamav api app"
}

variable "clamav_memory" {
  type        = number
  description = "Memory in MB to allocate to clamav app"
  default     = 3072
}

variable "max_file_size" {
  type        = string
  description = "Maximum file size the API will accept for scanning"
}
