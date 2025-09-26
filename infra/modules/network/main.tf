data "aws_availability_zones" "available" {}

locals {
  public_subnet_offset   = 10 # e.g. 10.0.0.0/20 -> 10.0.10.0
  private_subnet_offset  = 0  # e.g. 10.0.0.0/20 -> 10.0.0.0
  database_subnet_offset = 5  # e.g. 10.0.0.0/20 -> 10.0.5.0

  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.num_availability_zones)
}

module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name = var.name
  azs  = local.availability_zones
  cidr = var.vpc_cidr

  # Public subnets
  public_subnets     = [for i in range(var.num_availability_zones) : cidrsubnet(var.vpc_cidr, 4, local.public_subnet_offset + i)]
  public_subnet_tags = { subnet_type = "public" }

  # Private subnets
  private_subnets     = [for i in range(var.num_availability_zones) : cidrsubnet(var.vpc_cidr, 4, local.private_subnet_offset + i)]
  private_subnet_tags = { subnet_type = "private" }

  # Database subnets
  # `database_subnet_tags` is only used if `database_subnets` is not empty
  # `database_subnet_group_name` is only used if `create_database_subnet_group` is true
  database_subnets             = [for i in range(var.num_availability_zones) : cidrsubnet(var.vpc_cidr, 4, local.database_subnet_offset + i)]
  database_subnet_tags         = { subnet_type = "database" }
  create_database_subnet_group = true
  database_subnet_group_name   = var.database_subnet_group_name

  # If application needs external services, then create one NAT gateway per availability zone
  enable_nat_gateway     = var.has_external_non_aws_service
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.has_external_non_aws_service

  enable_dns_hostnames = true
  enable_dns_support   = true
}
