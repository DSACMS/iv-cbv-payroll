locals {
  # Machine readable project name (lower case letters, dashes, and underscores)
  # This will be used in names of AWS resources
  project_name = "iv-cbv-payroll"

  # Project owner (e.g. navapbc). Used for tagging infra resources.
  owner = "Digital-Public-Works"

  # URL of project source code repository
  code_repository_url = "https://github.com/Digital-Public-Works/iv-cbv-payroll"

  # Default AWS region for project (e.g. us-east-1, us-east-2, us-west-1).
  # This is dependent on where your project is located (if regional)
  # otherwise us-east-1 is a good default
  default_region = "us-east-1"

  github_actions_role_name = "${local.project_name}-github-actions"

  aws_services_security_group_name_prefix = "aws-service-vpc-endpoints"
}
