###
# Target space/org
###

data "cloudfoundry_space" "space" {
  org_name = var.cf_org_name
  name     = var.cf_space_name
}

data "cloudfoundry_domain" "internal" {
  name = "apps.internal"
}

data "cloudfoundry_app" "app" {
  name_or_id = "iv_cbv_payroll-${var.env}"
  space = data.cloudfoundry_space.space.id
}

###
# ClamAV API app
###

resource "cloudfoundry_route" "clamav_route" {
  space    = data.cloudfoundry_space.space.id
  domain   = data.cloudfoundry_domain.internal.id
  hostname = "iv_cbv_payroll-clamapi-${var.env}"
}

resource "cloudfoundry_app" "clamav_api" {
  name         = "iv_cbv_payroll-clamav-api-${var.env}"
  space        = data.cloudfoundry_space.space.id
  memory       = var.clamav_memory
  disk_quota   = 2048
  timeout      = 600
  docker_image = var.clamav_image
  routes {
    route = cloudfoundry_route.clamav_route.id
  }
  environment = {
    MAX_FILE_SIZE = var.max_file_size
  }
}

resource "cloudfoundry_network_policy" "clamav_routing" {
  policy {
    source_app      = data.cloudfoundry_app.app.id
    destination_app = cloudfoundry_app.clamav_api.id
    port            = "9443"
  }
}
