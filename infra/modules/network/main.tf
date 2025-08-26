data "aws_availability_zones" "available" {}

locals {
  vpc_cidr = "10.0.0.0/20"
  azs      = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # slice fixed CIDRs to requested AZ count
  public_subnets   = slice(["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"], 0, var.az_count)
  private_subnets  = slice(["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"], 0, var.az_count)
  database_subnets = slice(["10.0.5.0/24", "10.0.6.0/24", "10.0.7.0/24"], 0, var.az_count)
}

module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name = var.name
  azs  = local.azs
  cidr = local.vpc_cidr

  public_subnets     = local.public_subnets
  public_subnet_tags = { subnet_type = "public" }

  private_subnets     = local.private_subnets
  private_subnet_tags = { subnet_type = "private" }

  database_subnets             = local.database_subnets
  database_subnet_tags         = { subnet_type = "database" }
  create_database_subnet_group = true
  database_subnet_group_name   = var.database_subnet_group_name

  # NAT must exist if single_nat_gateway=true (dev) OR has_external_non_aws_service=true
  enable_nat_gateway     = var.has_external_non_aws_service || var.single_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !(var.single_nat_gateway)

  enable_dns_hostnames = true
  enable_dns_support   = true
}
