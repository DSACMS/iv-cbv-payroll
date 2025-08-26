locals {
  network_configs = {
    demo = {
      account_name               = "demo"
      database_subnet_group_name = "dev"

      # single-AZ dev & endpoint toggles
      az_count            = 1     # one AZ in dev
      single_nat_gateway  = true  # one NAT in dev
      enable_private_ecr  = false # use NAT for ECR in dev
      enable_db_endpoints = false # use NAT for KMS/SSM/Secrets in dev

      domain_config = {
        manage_dns  = false
        hosted_zone = "divt.app"

        certificate_configs = {
          "demo.divt.app" = {
            source                    = "issued"
            subject_alternative_names = ["*.divt.app", "*.demo.divt.app"]
          }
        }
      }
    }

    prod = {
      account_name               = "prod"
      database_subnet_group_name = "prod"

      # prod defaults (tune as needed)
      az_count            = 2
      single_nat_gateway  = false
      enable_private_ecr  = true
      enable_db_endpoints = true

      domain_config = {
        manage_dns  = false
        hosted_zone = "verifymyincome.org"

        certificate_configs = {
          "verifymyincome.org" = {
            source                    = "issued"
            subject_alternative_names = ["*.verifymyincome.org"]
          }
        }
      }
    }

    # staging can be added later if needed
  }
}
