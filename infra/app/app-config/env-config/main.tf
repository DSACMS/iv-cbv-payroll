locals {
  # The prefix is used to create uniquely named resources per terraform workspace, which
  # are needed in CI/CD for preview environments and tests.
  #
  # To isolate changes during infrastructure development by using manually created
  # terraform workspaces, see: /docs/infra/develop-and-test-infrastructure-in-isolation-using-workspaces.md
  prefix = terraform.workspace == "default" ? "" : "${terraform.workspace}-"

  bucket_name = "${local.prefix}${var.project_name}-${var.app_name}-${var.environment}"

  massachusetts_moveit_bucket_name = "${local.prefix}${var.project_name}-${var.app_name}-ma-moveit-${var.environment}"
}
