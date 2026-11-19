variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "email_addresses" {
  type    = list(string)
  default = []
}

variable "availability_enabled" {
  type    = bool
  default = false
}

variable "site_ids" {
  type = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_monitor_action_group" "this" {
  name                = "ag-${var.name_prefix}-high"
  resource_group_name = var.resource_group_name
  short_name          = "ramhigh"
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = toset(var.email_addresses)
    content {
      name                    = "oncall-${substr(md5(email_receiver.value), 0, 8)}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

locals {
  alerts = {
    api_failures = {
      description = "Elevated failed API request count."
      query       = "AppRequests | where TimeGenerated > ago(5m) and Success == false | summarize failures=count() by bin(TimeGenerated, 5m) | where failures >= 5"
    }
    function_failures = {
      description = "Function application exceptions detected."
      query       = "AppExceptions | where TimeGenerated > ago(5m) and AppRoleName has 'func' | summarize failures=count() by bin(TimeGenerated, 5m) | where failures > 0"
    }
    sql_connectivity = {
      description = "Application SQL connectivity failures detected."
      query       = "AppExceptions | where TimeGenerated > ago(5m) and (ExceptionType has 'Sql' or OuterMessage has 'SQL' or OuterMessage has 'database') | summarize failures=count() by bin(TimeGenerated, 5m) | where failures > 0"
    }
    adf_pipeline_failures = {
      description = "Azure Data Factory pipeline failures detected."
      query       = "AzureDiagnostics | where TimeGenerated > ago(5m) and ResourceProvider == 'MICROSOFT.DATAFACTORY' and Category == 'PipelineRuns' and status_s == 'Failed' | summarize failures=count() by bin(TimeGenerated, 5m) | where failures > 0"
    }
  }
  alert_definitions = merge(local.alerts, var.availability_enabled ? {
    application_downtime = {
      description = "Frontend availability test reported an outage."
      query       = "AppAvailabilityResults | where TimeGenerated > ago(5m) and Success == false | summarize failures=count() by bin(TimeGenerated, 5m) | where failures > 0"
    }
  } : {})
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "this" {
  for_each = local.alert_definitions

  name                 = "alert-${var.name_prefix}-${each.key}"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [var.log_analytics_workspace_id]
  description          = each.value.description
  enabled              = true
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  severity             = 1
  tags                 = var.tags

  criteria {
    query                   = each.value.query
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }
}

resource "azurerm_monitor_metric_alert" "web_app_health" {
  for_each = var.site_ids

  name                = "alert-${var.name_prefix}-${each.key}-downtime"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Application health check reports no healthy instances."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}
