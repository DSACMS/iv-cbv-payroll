locals {
  aws_service_integrations = setunion(
    # ECR only when explicitly enabled
    var.enable_private_ecr ? ["ecr.api", "ecr.dkr"] : [],

    # S3 always as a gateway endpoint
    ["s3"],

    # DB lambda private path (opt-in)
    (var.has_database && var.enable_db_endpoints) ? ["ssm", "kms", "secretsmanager"] : [],

    # ECS Exec / Session Manager: full trio
    var.enable_command_execution ? ["ssm", "ssmmessages", "ec2messages"] : []
  )

  interface_vpc_endpoints = toset([
    for svc in local.aws_service_integrations : svc
    if !contains(["s3", "dynamodb"], svc)
  ])
  gateway_vpc_endpoints = toset([
    for svc in local.aws_service_integrations : svc
    if contains(["s3", "dynamodb"], svc)
  ])

  # Put all Interface endpoints in one subnet (first private subnet)
  interface_endpoint_subnet_ids = [module.aws_vpc.private_subnets[0]]
}

data "aws_region" "current" {}

resource "aws_security_group" "aws_services" {
  name_prefix = var.aws_services_security_group_name_prefix
  description = "VPC endpoints to access AWS services from the VPCs private subnets"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.aws_vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = local.interface_vpc_endpoints
  vpc_id              = module.aws_vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.aws_services.id]
  subnet_ids          = local.interface_endpoint_subnet_ids
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_vpc_endpoints

  vpc_id            = module.aws_vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.aws_vpc.private_route_table_ids
}
