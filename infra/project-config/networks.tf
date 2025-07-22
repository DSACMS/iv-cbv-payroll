locals {
  network_configs = {
    demo = {
      account_name               = "demo"
      database_subnet_group_name = "demo"

      domain_config = {
        manage_dns  = false
        hosted_zone = "example.com"

        certificate_configs = {
          # Example certificate configuration for a certificate that is managed by the project
          # "sub.domain.com" = {
          #   source = "issued"
          # }

          # Example certificate configuration for a certificate that is issued elsewhere and imported into the project
          # (currently not supported, will be supported via https://github.com/navapbc/template-infra/issues/559)
          # "platform-test-dev.navateam.com" = {
          #   source = "imported"
          #   private_key_ssm_name = "/certificates/sub.domain.com/private-key"
          #   certificate_body_ssm_name = "/certificates/sub.domain.com/certificate-body"
          # }
        }
      }

      single_nat_gateway = true
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
