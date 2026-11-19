[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("dev", "test", "prod")]
    [string]$Environment,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$backendConfig = "environments\$Environment\backend.hcl"
$variablesFile = "environments\$Environment\terraform.tfvars"

if (-not (Test-Path $backendConfig)) {
    throw "Backend configuration '$backendConfig' was not found."
}

terraform init -input=false -backend-config="$backendConfig"
if ($LASTEXITCODE -ne 0) {
    throw "terraform init failed."
}

terraform plan -input=false -var-file="$variablesFile" -out="terraform-$Environment.tfplan"
if ($LASTEXITCODE -ne 0) {
    throw "terraform plan failed."
}

if ($Apply) {
    terraform apply -input=false "terraform-$Environment.tfplan"
    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply failed."
    }
}
