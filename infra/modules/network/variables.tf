variable "num_availability_zones" {
  type        = number
  description = "Number of availability zones (AZs) to provision across"
  validation {
    condition     = var.num_availability_zones > 0 && var.num_availability_zones <= 5
    error_message = "Number of availability zones must be between 1 and 5 (inclusive)"
  }
}

variable "aws_services_security_group_name_prefix" {
  type        = string
  description = "Prefix for the name of the security group attached to VPC endpoints"
}

variable "database_subnet_group_name" {
  type        = string
  description = "Name of the database subnet group"
}

variable "enable_command_execution" {
  type        = bool
  description = "Whether the application(s) in this network need ECS Exec access. Determines whether to create VPC endpoints needed by ECS Exec."
  default     = false
}

variable "has_database" {
  type        = bool
  description = "Whether the application(s) in this network have a database. Determines whether to create VPC endpoints needed by the database layer."
  default     = false
}

variable "has_external_non_aws_service" {
  type        = bool
  description = "Whether the application(s) in this network need to call external non-AWS services. Determines whether or not to create NAT gateways."
  default     = false
}

variable "single_nat_gateway" {
  type        = bool
  description = "Whether to provision only a single NAT gateway, rather than one per AZ. Good for saving costs in non-production environments."
  default     = false
}

variable "name" {
  type        = string
  description = "Name to give the VPC. Will be added to the VPC under the 'network_name' tag."
}
