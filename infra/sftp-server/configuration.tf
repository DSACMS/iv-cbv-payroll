variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "az_list" {
  description = "AWS availability zones"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "storage_bucket_name_prefix" {
  description = "Prefix for the bucket name to store the files in"
  default     = "sftp-s3-bucket-"
}

variable "transer_familiy_default_user" {
  description = "The Username for the SFTP server"
  default     = "sftpuser"
}

variable "allowed_incoming_cidr_list" {
  description = "List of CIDR blocks to allow incoming traffic from for the SFTP server"
  default     = ["0.0.0.0/0"]
}


