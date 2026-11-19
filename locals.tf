locals {
  name_prefix   = "${var.project}-${var.environment}"
  unique_suffix = var.name_suffix != "" ? var.name_suffix : substr(sha256(data.azurerm_client_config.current.subscription_id), 0, 6)
  unique_name   = "${local.name_prefix}-${local.unique_suffix}"
  common_tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  })

  sql_database_names = {
    landing_zone = "${local.name_prefix}-landing"
    ram          = "${local.name_prefix}-ram"
  }
}

data "azurerm_client_config" "current" {}
