# RAM-Collins Azure Terraform

Terraform infrastructure for the RAM-Collins application. It creates private-by-default Azure networking, frontend/backend App Services, Azure SQL databases, Data Factory, Function App and identity-based storage, Key Vault, monitoring, alerts, and isolated dev/test/prod state configurations.

## Quick start

1. Install Terraform 1.9.8 and Azure CLI; authenticate to the target subscription.
2. Deploy `bootstrap/` once to create the Azure Storage remote-state account. See [deployment guide](docs/deployment.md).
3. Configure the state account name in each `environments/<env>/backend.hcl`.
4. Provide SQL Entra administrator variables and review environment sizing, alert recipients, network CIDRs, and naming suffix.
5. Run `.\scripts\Validate-Terraform.ps1`, then `.\scripts\Deploy.ps1 -Environment dev`.
6. Apply the reviewed plan and run the SQL contained-user grant script for backend and Data Factory identities.
7. Deploy application code and Data Factory pipelines separately; configure provider-specific email integration and Key Vault secret values outside Terraform.

See [architecture](docs/architecture.md), [networking](docs/networking.md), [security](docs/security.md), and [monitoring](docs/monitoring.md).

## Repository layout

```text
.
├── .github/workflows/       # Validation/security and OIDC deployment pipelines
├── bootstrap/               # Remote-state resource group and Storage Account
├── docs/                    # Architecture, networking, security, monitoring, deployment
├── environments/            # Independent dev, test, and prod inputs/state keys
├── modules/                 # Reusable Azure resource modules
├── scripts/                 # Validation, deployment, SQL identity bootstrap
├── main.tf                  # Environment composition
├── variables.tf             # Tunable infrastructure and identity inputs
└── versions.tf              # Terraform/AzureRM pin and backend declaration
```

## Important deployment notes

- This repository provisions platform resources; it does not contain application code, ADF pipelines, SQL schema/migrations, or the email provider implementation.
- SQL server authentication is Microsoft Entra-only. Terraform deliberately does not collect SQL passwords or embed SQL execution credentials. Database-contained identities are provisioned after deployment by the included Entra-authenticated script.
- `availability_test_url` is optional and should only be set for a publicly reachable endpoint. Public service access defaults to disabled.
- For CI, configure GitHub OIDC federation and environment protection. No Azure client secret is used by the workflows.
- Terraform state is security-sensitive. Keep it in the private remote backend and do not commit `.tfstate`, `.tfplan`, credentials, or secret values.
