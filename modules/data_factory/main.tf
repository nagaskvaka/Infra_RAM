variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "sql_server_id" {
  type = string
}

variable "sql_server_fqdn" {
  type = string
}

variable "sql_database_names" {
  type = map(string)
}

variable "storage_account_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_data_factory" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  public_network_enabled          = var.public_network_access_enabled
  managed_virtual_network_enabled = true
  tags                            = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_data_factory_integration_runtime_azure" "managed" {
  name                    = "managed-ir"
  data_factory_id         = azurerm_data_factory.this.id
  location                = "AutoResolve"
  virtual_network_enabled = true
}

resource "azurerm_data_factory_managed_private_endpoint" "sql" {
  name               = "sql-server"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.sql_server_id
  subresource_name   = "sqlServer"
}

resource "azurerm_data_factory_managed_private_endpoint" "key_vault" {
  name               = "key-vault"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.key_vault_id
  subresource_name   = "vault"
}

resource "azurerm_data_factory_managed_private_endpoint" "storage_blob" {
  name               = "storage-blob"
  data_factory_id    = azurerm_data_factory.this.id
  target_resource_id = var.storage_account_id
  subresource_name   = "blob"
}

resource "azurerm_data_factory_linked_service_key_vault" "this" {
  name            = "key-vault"
  data_factory_id = azurerm_data_factory.this.id
  key_vault_id    = var.key_vault_id
}

resource "azurerm_data_factory_linked_service_azure_sql_database" "this" {
  for_each = var.sql_database_names

  name                     = "sql-${each.key}"
  data_factory_id          = azurerm_data_factory.this.id
  connection_string        = "Server=tcp:${var.sql_server_fqdn},1433;Database=${each.value};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  use_managed_identity     = true
  integration_runtime_name = azurerm_data_factory_integration_runtime_azure.managed.name
  description              = "Managed identity connection to the ${each.key} database."
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_data_factory.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = ["PipelineRuns", "ActivityRuns", "TriggerRuns"]
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
  }
}

output "id" {
  value = azurerm_data_factory.this.id
}

output "name" {
  value = azurerm_data_factory.this.name
}

output "principal_id" {
  value = azurerm_data_factory.this.identity[0].principal_id
}
