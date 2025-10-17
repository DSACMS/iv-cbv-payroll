locals {
  # Machine readable project name (lower case letters, dashes, and underscores)
  # This will be used in names of AWS resources
  project_name = "iv-cbv-payroll"

  # Project owner (e.g. navapbc). Used for tagging infra resources.
  owner = "DSACMS"

  # URL of project source code repository
  code_repository_url = "https://github.com/DSACMS/iv-cbv-payroll"

  # Default AWS region for project (e.g. us-east-1, us-east-2, us-west-1).
  # This is dependent on where your project is located (if regional)
  # otherwise us-east-1 is a good default
  default_region = "us-east-1"

  # The name of the IAM role created by this terraform template
  # that the GitHub Action will assume when running CI/CD operations.
  github_actions_role_name = "${local.project_name}-github-actions"

  # Prefix for AWS security group name used for VPC endpoints to access AWS services
  # from the VPCs private subnets
  aws_services_security_group_name_prefix = "aws-service-vpc-endpoints"
}
