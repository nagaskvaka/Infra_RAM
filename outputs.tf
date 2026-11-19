output "resource_group_name" {
  description = "Application resource group."
  value       = module.resource_group.name
}

output "frontend_url" {
  description = "Frontend App Service URL. Inbound access may require private network connectivity."
  value       = module.app_services.frontend_url
}

output "backend_url" {
  description = "Backend App Service URL. Inbound access may require private network connectivity."
  value       = module.app_services.backend_url
}

output "function_app_name" {
  description = "Function App resource name."
  value       = module.function_app.name
}

output "sql_server_fqdn" {
  description = "Azure SQL server FQDN."
  value       = module.sql_server.fqdn
}

output "sql_database_names" {
  description = "Provisioned SQL database names."
  value       = values(local.sql_database_names)
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.key_vault.uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID."
  value       = module.monitoring.log_analytics_workspace_id
}

output "backend_managed_identity_principal_id" {
  description = "Principal ID of the backend user-assigned managed identity for SQL database provisioning."
  value       = module.backend_identity.principal_id
}

output "data_factory_managed_identity_principal_id" {
  description = "Principal ID of the Data Factory system-assigned identity for SQL database provisioning."
  value       = module.data_factory.principal_id
}

output "function_managed_identity_principal_id" {
  description = "Principal ID of the Function App user-assigned managed identity."
  value       = module.function_identity.principal_id
}
