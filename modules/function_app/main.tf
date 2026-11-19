variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "plan_sku" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "public_network_access_enabled" {
  type = bool
}

variable "public_ip_rules" {
  type = list(object({
    name       = string
    ip_address = string
    priority   = number
  }))
}

variable "app_subnet_id" {
  type = string
}

variable "identity_id" {
  type = string
}

variable "key_vault_uri" {
  type = string
}

variable "app_insights_connection_string" {
  type = string
}

variable "app_settings" {
  type    = map(string)
  default = {}
}

variable "key_vault_secret_names" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "log_analytics_workspace_id" {
  type = string
}

locals {
  vault_references = {
    for setting, secret in var.key_vault_secret_names :
    setting => "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/${secret})"
  }
}

resource "azurerm_service_plan" "this" {
  name                = "plan-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.plan_sku
  tags                = var.tags
}

resource "azurerm_linux_function_app" "this" {
  name                                           = var.name
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.this.id
  storage_account_name                           = var.storage_account_name
  storage_uses_managed_identity                  = true
  virtual_network_subnet_id                      = var.app_subnet_id
  public_network_access_enabled                  = var.public_network_access_enabled
  https_only                                     = true
  functions_extension_version                    = "~4"
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  key_vault_reference_identity_id                = var.identity_id
  app_settings = merge(var.app_settings, local.vault_references, {
    APPLICATIONINSIGHTS_CONNECTION_STRING = var.app_insights_connection_string
    AzureWebJobsStorage__accountName      = var.storage_account_name
    AzureWebJobsStorage__credential       = "managedidentity"
    WEBSITE_CONTENTOVERVNET               = "1"
    WEBSITE_RUN_FROM_PACKAGE              = "1"
  })
  tags = var.tags

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [var.identity_id]
  }

  site_config {
    always_on                         = true
    ftps_state                        = "Disabled"
    health_check_path                 = "/api/health"
    health_check_eviction_time_in_min = 2
    minimum_tls_version               = "1.2"
    ip_restriction_default_action     = "Deny"

    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }

    dynamic "ip_restriction" {
      for_each = var.public_ip_rules
      content {
        name       = ip_restriction.value.name
        ip_address = ip_restriction.value.ip_address
        priority   = ip_restriction.value.priority
        action     = "Allow"
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_linux_function_app.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FunctionAppLogs"
  }

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServicePlatformLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

output "id" {
  value = azurerm_linux_function_app.this.id
}

output "name" {
  value = azurerm_linux_function_app.this.name
}

output "principal_id" {
  value = azurerm_linux_function_app.this.identity[0].principal_id
}

output "default_hostname" {
  value = azurerm_linux_function_app.this.default_hostname
}
