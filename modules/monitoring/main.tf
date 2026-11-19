variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "log_retention_days" {
  type = number
}

variable "availability_test_url" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "appi-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_application_insights_standard_web_test" "frontend" {
  count                   = var.availability_test_url == "" ? 0 : 1
  name                    = "webtest-${var.name_prefix}-frontend"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.this.id
  description             = "HTTPS availability probe for the RAM-Collins frontend"
  geo_locations           = ["us-va-ash-azr", "us-tx-sn1-azr", "us-il-ch1-azr"]
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  retry_enabled           = true
  tags                    = var.tags

  request {
    url = var.availability_test_url
  }

  validation_rules {
    expected_status_code        = 200
    ssl_check_enabled           = true
    ssl_cert_remaining_lifetime = 7
  }
}

resource "azurerm_application_insights_workbook" "this" {
  name                = "workbook-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = "RAM-Collins application health"
  category            = "workbook"
  source_id           = azurerm_application_insights.this.id
  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 3
        name = "Request failures"
        content = {
          version      = "KqlItem/1.0"
          query        = "AppRequests | where TimeGenerated > ago(24h) | summarize Requests=count(), Failures=countif(Success == false) by bin(TimeGenerated, 1h) | render timechart"
          size         = 0
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
      },
      {
        type = 3
        name = "Application exceptions"
        content = {
          version      = "KqlItem/1.0"
          query        = "AppExceptions | where TimeGenerated > ago(24h) | summarize Exceptions=count() by bin(TimeGenerated, 1h) | render timechart"
          size         = 0
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
      }
    ]
  })
  tags = var.tags
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "app_insights_id" {
  value = azurerm_application_insights.this.id
}

output "app_insights_connection_string" {
  value     = azurerm_application_insights.this.connection_string
  sensitive = true
}
