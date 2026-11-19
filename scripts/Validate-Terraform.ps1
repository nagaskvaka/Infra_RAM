[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

terraform fmt -recursive -check
if ($LASTEXITCODE -ne 0) {
    throw "terraform fmt failed."
}

terraform init -backend=false -input=false -no-color
if ($LASTEXITCODE -ne 0) {
    throw "terraform init failed."
}

terraform validate -no-color
if ($LASTEXITCODE -ne 0) {
    throw "terraform validate failed."
}

terraform -chdir=bootstrap init -backend=false -input=false -no-color
if ($LASTEXITCODE -ne 0) {
    throw "bootstrap terraform init failed."
}

terraform -chdir=bootstrap validate -no-color
if ($LASTEXITCODE -ne 0) {
    throw "bootstrap terraform validate failed."
}

if (Get-Command checkov -ErrorAction SilentlyContinue) {
    checkov -d . --framework terraform --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "Checkov reported a failure."
    }
} else {
    Write-Warning "Checkov is not installed; Terraform validation completed without security scanning."
}
