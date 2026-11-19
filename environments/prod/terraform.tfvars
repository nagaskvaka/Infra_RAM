environment                           = "prod"
location                              = "eastus2"
sql_database_sku                      = "GP_S_Gen5_2"
sql_short_term_retention_days         = 35
sql_weekly_backup_retention           = "P12W"
sql_monthly_backup_retention          = "P12M"
sql_yearly_backup_retention           = "P5Y"
sql_enable_long_term_backup_retention = true
sql_week_of_year                      = 1
app_service_plan_sku                  = "P1v3"
function_plan_sku                     = "EP1"
log_retention_days                    = 365
enable_public_app_access              = false
enable_public_adf_access              = false
enable_public_storage_access          = false
alert_email_addresses                 = []

