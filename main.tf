module "resource_group" {
  source   = "./modules/resource_group"
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

module "networking" {
  source                           = "./modules/networking"
  name                             = "vnet-${local.name_prefix}"
  location                         = var.location
  resource_group_name              = module.resource_group.name
  address_space                    = var.vnet_address_space
  app_subnet_prefixes              = var.app_subnet_prefixes
  private_endpoint_subnet_prefixes = var.private_endpoint_subnet_prefixes
  tags                             = local.common_tags
}

module "monitoring" {
  source                = "./modules/monitoring"
  name_prefix           = local.name_prefix
  location              = var.location
  resource_group_name   = module.resource_group.name
  log_retention_days    = var.log_retention_days
  availability_test_url = var.availability_test_url
  tags                  = local.common_tags
}

module "key_vault" {
  source                     = "./modules/key_vault"
  name                       = "kv-${replace(local.name_prefix, "-", "")}${local.unique_suffix}"
  location                   = var.location
  resource_group_name        = module.resource_group.name
  tenant_id                  = var.sql_administrator_tenant_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

module "frontend_identity" {
  source              = "./modules/managed_identity"
  name                = "id-${local.name_prefix}-frontend"
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

module "backend_identity" {
  source              = "./modules/managed_identity"
  name                = "id-${local.name_prefix}-backend"
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

module "function_identity" {
  source              = "./modules/managed_identity"
  name                = "id-${local.name_prefix}-function"
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

module "storage" {
  source                        = "./modules/storage"
  name                          = "st${substr(replace(local.name_prefix, "-", ""), 0, 10)}${local.unique_suffix}"
  location                      = var.location
  resource_group_name           = module.resource_group.name
  public_network_access_enabled = var.enable_public_storage_access
  public_ip_rules               = var.public_storage_ip_rules
  tags                          = local.common_tags
}

module "sql_server" {
  source                     = "./modules/sql_server"
  name                       = "sql-${local.unique_name}"
  location                   = var.location
  resource_group_name        = module.resource_group.name
  administrator_name         = var.sql_administrator_name
  administrator_object_id    = var.sql_administrator_object_id
  administrator_tenant_id    = var.sql_administrator_tenant_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.common_tags
}

module "landing_zone_database" {
  source                            = "./modules/sql_database"
  name                              = local.sql_database_names.landing_zone
  server_id                         = module.sql_server.id
  sku_name                          = var.sql_database_sku
  short_term_retention_days         = var.sql_short_term_retention_days
  enable_long_term_backup_retention = var.sql_enable_long_term_backup_retention
  weekly_backup_retention           = var.sql_weekly_backup_retention
  monthly_backup_retention          = var.sql_monthly_backup_retention
  yearly_backup_retention           = var.sql_yearly_backup_retention
  week_of_year                      = var.sql_week_of_year
  tags                              = local.common_tags
}

module "ram_database" {
  source                            = "./modules/sql_database"
  name                              = local.sql_database_names.ram
  server_id                         = module.sql_server.id
  sku_name                          = var.sql_database_sku
  short_term_retention_days         = var.sql_short_term_retention_days
  enable_long_term_backup_retention = var.sql_enable_long_term_backup_retention
  weekly_backup_retention           = var.sql_weekly_backup_retention
  monthly_backup_retention          = var.sql_monthly_backup_retention
  yearly_backup_retention           = var.sql_yearly_backup_retention
  week_of_year                      = var.sql_week_of_year
  tags                              = local.common_tags
}

module "app_services" {
  source                         = "./modules/app_service"
  name_prefix                    = local.unique_name
  location                       = var.location
  resource_group_name            = module.resource_group.name
  app_service_plan_sku           = var.app_service_plan_sku
  app_subnet_id                  = module.networking.app_subnet_id
  public_network_access_enabled  = var.enable_public_app_access
  public_ip_rules                = var.public_app_ip_rules
  frontend_identity_id           = module.frontend_identity.id
  backend_identity_id            = module.backend_identity.id
  key_vault_uri                  = module.key_vault.uri
  app_insights_connection_string = module.monitoring.app_insights_connection_string
  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  frontend_health_check_path     = var.frontend_health_check_path
  backend_health_check_path      = var.backend_health_check_path
  frontend_app_settings          = var.frontend_app_settings
  backend_app_settings = merge(var.backend_app_settings, {
    SQL_SERVER_FQDN                = module.sql_server.fqdn
    SQL_LANDING_ZONE_DATABASE      = module.landing_zone_database.name
    SQL_RAM_DATABASE               = module.ram_database.name
    SQL_AUTHENTICATION             = "Active Directory Managed Identity"
    SQL_MANAGED_IDENTITY_CLIENT_ID = module.backend_identity.client_id
  })
  key_vault_secret_names = var.app_key_vault_secret_names
  tags                   = local.common_tags
  depends_on             = [module.role_assignments]
}

module "data_factory" {
  source                        = "./modules/data_factory"
  name                          = "adf-${local.unique_name}"
  location                      = var.location
  resource_group_name           = module.resource_group.name
  public_network_access_enabled = var.enable_public_adf_access
  log_analytics_workspace_id    = module.monitoring.log_analytics_workspace_id
  key_vault_id                  = module.key_vault.id
  sql_server_id                 = module.sql_server.id
  sql_server_fqdn               = module.sql_server.fqdn
  sql_database_names            = local.sql_database_names
  storage_account_id            = module.storage.id
  tags                          = local.common_tags
}

module "function_app" {
  source                         = "./modules/function_app"
  name                           = "func-${local.unique_name}"
  location                       = var.location
  resource_group_name            = module.resource_group.name
  plan_sku                       = var.function_plan_sku
  storage_account_name           = module.storage.name
  public_network_access_enabled  = var.enable_public_app_access
  public_ip_rules                = var.public_app_ip_rules
  app_subnet_id                  = module.networking.app_subnet_id
  identity_id                    = module.function_identity.id
  key_vault_uri                  = module.key_vault.uri
  app_insights_connection_string = module.monitoring.app_insights_connection_string
  app_settings                   = var.function_app_settings
  key_vault_secret_names         = var.function_key_vault_secret_names
  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  tags                           = local.common_tags
  depends_on                     = [module.role_assignments]
}

module "alerts" {
  source                     = "./modules/alerts"
  name_prefix                = local.unique_name
  location                   = var.location
  resource_group_name        = module.resource_group.name
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  email_addresses            = var.alert_email_addresses
  availability_enabled       = var.availability_test_url != ""
  site_ids = {
    frontend = module.app_services.frontend_id
    backend  = module.app_services.backend_id
    function = module.function_app.id
  }
  tags = local.common_tags
}

module "private_endpoints" {
  source              = "./modules/private_endpoint"
  location            = var.location
  resource_group_name = module.resource_group.name
  subnet_id           = module.networking.private_endpoint_subnet_id
  endpoints = {
    key_vault = {
      resource_id       = module.key_vault.id
      subresource_names = ["vault"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["vault"]]
    }
    sql = {
      resource_id       = module.sql_server.id
      subresource_names = ["sqlServer"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["sql"]]
    }
    frontend = {
      resource_id       = module.app_services.frontend_id
      subresource_names = ["sites"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["web"]]
    }
    backend = {
      resource_id       = module.app_services.backend_id
      subresource_names = ["sites"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["web"]]
    }
    function = {
      resource_id       = module.function_app.id
      subresource_names = ["sites"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["web"]]
    }
    storage_blob = {
      resource_id       = module.storage.id
      subresource_names = ["blob"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["blob"]]
    }
    storage_file = {
      resource_id       = module.storage.id
      subresource_names = ["file"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["file"]]
    }
    storage_queue = {
      resource_id       = module.storage.id
      subresource_names = ["queue"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["queue"]]
    }
    storage_table = {
      resource_id       = module.storage.id
      subresource_names = ["table"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["table"]]
    }
    data_factory = {
      resource_id       = module.data_factory.id
      subresource_names = ["dataFactory"]
      dns_zone_ids      = [module.networking.private_dns_zone_ids["adf"]]
    }
  }
  tags = local.common_tags
}

module "role_assignments" {
  source = "./modules/role_assignment"
  assignments = {
    backend_key_vault = {
      scope                = module.key_vault.id
      role_definition_name = "Key Vault Secrets User"
      principal_id         = module.backend_identity.principal_id
    }
    frontend_key_vault = {
      scope                = module.key_vault.id
      role_definition_name = "Key Vault Secrets User"
      principal_id         = module.frontend_identity.principal_id
    }
    function_key_vault = {
      scope                = module.key_vault.id
      role_definition_name = "Key Vault Secrets User"
      principal_id         = module.function_identity.principal_id
    }
    data_factory_key_vault = {
      scope                = module.key_vault.id
      role_definition_name = "Key Vault Secrets User"
      principal_id         = module.data_factory.principal_id
    }
    function_storage_blob = {
      scope                = module.storage.id
      role_definition_name = "Storage Blob Data Owner"
      principal_id         = module.function_identity.principal_id
    }
    function_storage_queue = {
      scope                = module.storage.id
      role_definition_name = "Storage Queue Data Contributor"
      principal_id         = module.function_identity.principal_id
    }
    function_storage_table = {
      scope                = module.storage.id
      role_definition_name = "Storage Table Data Contributor"
      principal_id         = module.function_identity.principal_id
    }
    function_storage_account = {
      scope                = module.storage.id
      role_definition_name = "Storage Account Contributor"
      principal_id         = module.function_identity.principal_id
    }
  }
}
