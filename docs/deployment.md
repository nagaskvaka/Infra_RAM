# Deployment guide

## Prerequisites

- Terraform 1.9.8 (the root pins AzureRM 4.0.1).
- Azure CLI authenticated to the target subscription and permissions to create the listed Azure resources and role assignments.
- A Microsoft Entra administrator object ID, tenant ID, and display name for Azure SQL.
- For CI: an Azure app registration/service principal configured for GitHub OIDC, a federated credential restricted to this repository/workflow, and a least-privilege role assignment. Configure the GitHub `dev`, `test`, and `prod` environments; protect `prod` with required reviewers.
- A globally unique, lowercase Storage Account name for the state account.

## 1. Bootstrap remote state

The bootstrap state starts locally because it creates the storage account that will host application state. Protect and back up the local bootstrap state, or configure a separately managed backend before running it.

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -var="storage_account_name=<globally-unique-name>"
terraform -chdir=bootstrap apply -var="storage_account_name=<globally-unique-name>"
```

The state account blocks public traffic except configured IPs and Azure trusted services. Add the operator/runner egress IPs using `allowed_ip_addresses`, or use a self-hosted runner with private network access. Assign the deployment principal `Storage Blob Data Contributor` on the state container/account; use Azure AD authentication rather than storage keys.

Replace `REPLACE_WITH_BOOTSTRAP_OUTPUT` in each `environments/<env>/backend.hcl` with the bootstrap output. The keys are different for each environment.

## 2. Configure deployment inputs

Edit the environment `.tfvars` sizing and `alert_email_addresses`. Set environment-specific non-secret settings in your own `.tfvars` (do not commit credentials). SQL administrator values are required variables and should be supplied as process environment variables:

```powershell
$env:ARM_SUBSCRIPTION_ID = "<subscription GUID>"
$env:TF_VAR_sql_administrator_name = "<Entra admin display name>"
$env:TF_VAR_sql_administrator_object_id = "<Entra admin object ID>"
$env:TF_VAR_sql_administrator_tenant_id = "<tenant GUID>"
```

Supply secret setting names using `app_key_vault_secret_names` and `function_key_vault_secret_names`. Terraform only writes Key Vault reference expressions into app settings; secret values must be provisioned separately through an approved secret-management process. Never put secret values in `.tfvars`, CI variables, command-line arguments, or Terraform outputs.

## 3. Plan and apply

Authenticate with `az login`, then use the deployment script:

```powershell
.\scripts\Deploy.ps1 -Environment dev
.\scripts\Deploy.ps1 -Environment dev -Apply
```

After the platform is provisioned, the SQL Entra administrator must grant database-contained permissions to the backend and Data Factory identities. Install the `SqlServer` PowerShell module and run:

```powershell
.\scripts\Grant-SqlManagedIdentityAccess.ps1 `
  -SqlServerFqdn "<terraform sql_server_fqdn output>" `
  -DatabaseNames @("<landing database>", "<RAM database>") `
  -IdentityNames @("<backend UAMI name>", "<Data Factory name>")
```

The script grants only `db_datareader` and `db_datawriter`; review these grants against application-specific least-privilege requirements. Add custom schema/EXECUTE permissions through reviewed database migrations where needed. Approve the Data Factory managed private endpoint connection requests in Azure SQL, Key Vault, and Storage if they remain pending.

## GitHub Actions

`Terraform CI` formats, initializes without remote state, validates, and runs Checkov on pull requests. `Terraform deployment` is manually dispatched: it creates a plan, stores the binary plan briefly, then applies that exact plan in the selected GitHub Environment. Set required reviewers on the `prod` environment to gate production applies.

Configure these repository/environment variables: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TF_STATE_RESOURCE_GROUP`, `TF_STATE_STORAGE_ACCOUNT`, `TF_STATE_CONTAINER`, `SQL_ADMINISTRATOR_NAME`, `SQL_ADMINISTRATOR_OBJECT_ID`, and `ALERT_EMAIL_ADDRESSES`. Set `ALERT_EMAIL_ADDRESSES` to a JSON string containing an array of email addresses (for example, `["oncall@example.com"]`). The deploy workflow uses OIDC and has no client secret. Restrict its federated identity to the repository and deployment workflow. Configure the Azure role for infrastructure changes separately from the narrowly scoped Blob data role used for state access.

## Destroy and recovery

Review the destroy plan carefully; Key Vault purge protection and soft delete intentionally complicate immediate deletion. Back up remote state and SQL recovery points before destructive changes. Keep the bootstrap resources until all environment states have been migrated or removed.
