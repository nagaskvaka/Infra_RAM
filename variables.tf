variable "project" {
  description = "Short project identifier used in resource names."
  type        = string
  default     = "ramcollins"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.project))
    error_message = "project must contain 2 to 10 lowercase letters or digits."
  }
}

variable "name_suffix" {
  description = "Optional short globally unique suffix. Defaults to a deterministic subscription-derived suffix."
  type        = string
  default     = ""

  validation {
    condition     = var.name_suffix == "" || can(regex("^[a-z0-9]{1,6}$", var.name_suffix))
    error_message = "name_suffix must be empty or 1 to 6 lowercase letters or digits."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Azure region for the application resources."
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Address space for the application virtual network."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "app_subnet_prefixes" {
  description = "CIDR prefixes for App Service VNet integration."
  type        = list(string)
  default     = ["10.40.1.0/24"]
}

variable "private_endpoint_subnet_prefixes" {
  description = "CIDR prefixes for private endpoints."
  type        = list(string)
  default     = ["10.40.2.0/24"]
}

variable "sql_administrator_name" {
  description = "Microsoft Entra administrator display name for Azure SQL."
  type        = string
}

variable "sql_administrator_object_id" {
  description = "Object ID of the Microsoft Entra SQL administrator."
  type        = string
}

variable "sql_administrator_tenant_id" {
  description = "Tenant ID of the Microsoft Entra SQL administrator."
  type        = string
}

variable "sql_database_sku" {
  description = "Azure SQL database SKU (for example, Basic or GP_S_Gen5_2)."
  type        = string
  default     = "Basic"
}

variable "sql_short_term_retention_days" {
  description = "Point-in-time restore retention for both databases."
  type        = number
  default     = 14

  validation {
    condition     = var.sql_short_term_retention_days >= 1 && var.sql_short_term_retention_days <= 35
    error_message = "sql_short_term_retention_days must be between 1 and 35."
  }
}

variable "sql_enable_long_term_backup_retention" {
  description = "Enable SQL long-term backup retention policies."
  type        = bool
  default     = false
}

variable "sql_weekly_backup_retention" {
  description = "Long-term weekly backup retention (for example, P4W)."
  type        = string
  default     = "P4W"
}

variable "sql_monthly_backup_retention" {
  description = "Long-term monthly backup retention (for example, P12M)."
  type        = string
  default     = "P12M"
}

variable "sql_yearly_backup_retention" {
  description = "Long-term yearly backup retention (for example, P5Y)."
  type        = string
  default     = "P1Y"
}

variable "sql_week_of_year" {
  description = "Week of year used for the yearly long-term backup."
  type        = number
  default     = 1

  validation {
    condition     = var.sql_week_of_year >= 1 && var.sql_week_of_year <= 52
    error_message = "sql_week_of_year must be between 1 and 52."
  }
}

variable "app_service_plan_sku" {
  description = "SKU for the frontend and backend Linux App Service Plans."
  type        = string
  default     = "P1v3"
}

variable "function_plan_sku" {
  description = "Elastic Premium SKU for the Linux Function App."
  type        = string
  default     = "EP1"
}

variable "frontend_health_check_path" {
  description = "Frontend health-check endpoint."
  type        = string
  default     = "/health"
}

variable "backend_health_check_path" {
  description = "Backend health-check endpoint."
  type        = string
  default     = "/health"
}

variable "frontend_app_settings" {
  description = "Non-secret frontend application settings."
  type        = map(string)
  default     = {}
}

variable "backend_app_settings" {
  description = "Non-secret backend application settings."
  type        = map(string)
  default     = {}
}

variable "function_app_settings" {
  description = "Non-secret Function App application settings."
  type        = map(string)
  default     = {}
}

variable "app_key_vault_secret_names" {
  description = "Application setting name to existing Key Vault secret name mappings. Secret values are never managed here."
  type        = map(string)
  default     = {}
}

variable "function_key_vault_secret_names" {
  description = "Function setting name to existing Key Vault secret name mappings. Secret values are never managed here."
  type        = map(string)
  default     = {}
}

variable "enable_public_app_access" {
  description = "Allow public inbound access to App Services; private endpoints remain provisioned."
  type        = bool
  default     = false
}

variable "enable_public_adf_access" {
  description = "Allow public access to the Data Factory endpoint."
  type        = bool
  default     = false
}

variable "enable_public_storage_access" {
  description = "Enable the Function storage account public endpoint; only public_storage_ip_rules are allowed."
  type        = bool
  default     = false
}

variable "public_storage_ip_rules" {
  description = "IPv4 addresses allowed through the Storage Account firewall when public access is enabled."
  type        = list(string)
  default     = []
}

variable "public_app_ip_rules" {
  description = "IP allow-list for public App Service endpoints. With no rules, public endpoint traffic remains denied."
  type = list(object({
    name       = string
    ip_address = string
    priority   = number
  }))
  default = []

  validation {
    condition = (
      alltrue([for rule in var.public_app_ip_rules : rule.priority >= 100 && rule.priority <= 65000]) &&
      length(distinct([for rule in var.public_app_ip_rules : rule.priority])) == length(var.public_app_ip_rules)
    )
    error_message = "App Service IP rule priorities must be unique and between 100 and 65000."
  }
}

variable "availability_test_url" {
  description = "Optional publicly reachable HTTPS URL to probe. Leave empty for private-only apps."
  type        = string
  default     = ""
}

variable "alert_email_addresses" {
  description = "Email addresses that receive high-priority Azure Monitor alerts."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 90

  validation {
    condition     = contains([30, 60, 90, 120, 180, 270, 365, 550, 730], var.log_retention_days)
    error_message = "log_retention_days must be a supported Application Insights retention value."
  }
}
