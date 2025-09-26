locals {
  network_configs = {
    demo = {
      account_name               = "demo"
      database_subnet_group_name = "dev"

      domain_config = {
        manage_dns  = false
        hosted_zone = "divt.app"

        certificate_configs = {
          # Example certificate configuration for a certificate that is managed by the project
          "demo.divt.app" = {
            source                    = "issued"
            subject_alternative_names = ["*.divt.app", "*.demo.divt.app"]
          }
        }
      }

      vpc_cidr               = "10.0.0.0/20"
      num_availability_zones = 3
      single_nat_gateway     = true
    }

    prod = {
      account_name               = "prod"
      database_subnet_group_name = "prod"

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

      vpc_cidr               = "10.0.0.0/20"
      num_availability_zones = 3
      single_nat_gateway     = true
    }
    # staging = {
    #   account_name               = "staging"
    #   database_subnet_group_name = "staging"

    #   domain_config = {
    #     manage_dns  = true
    #     hosted_zone = "hosted.zone.for.staging.network.com"

    #     certificate_configs = {}
    #   }
    # }
  }
}
