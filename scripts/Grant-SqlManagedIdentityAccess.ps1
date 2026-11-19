[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SqlServerFqdn,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$DatabaseNames,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$IdentityNames
)

$ErrorActionPreference = "Stop"

$sqlCommand = Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue
if (-not $sqlCommand) {
    throw "Invoke-Sqlcmd was not found. Install the SqlServer PowerShell module and retry."
}
if (-not $sqlCommand.Parameters.ContainsKey("AccessToken")) {
    throw "The installed SqlServer module does not support Invoke-Sqlcmd -AccessToken. Update the module and retry."
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI was not found. Install Azure CLI, run az login, and retry."
}

$accessToken = az account get-access-token --resource "https://database.windows.net/" --query accessToken --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accessToken)) {
    throw "Unable to acquire a Microsoft Entra access token for Azure SQL. Run az login and retry."
}

foreach ($databaseName in $DatabaseNames) {
    foreach ($identityName in $IdentityNames) {
        $escapedLiteral = $identityName.Replace("'", "''")
        $escapedIdentifier = $identityName.Replace("]", "]]")
        $query = @"
IF USER_ID(N'$escapedLiteral') IS NULL
    CREATE USER [$escapedIdentifier] FROM EXTERNAL PROVIDER;
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members AS membership
    INNER JOIN sys.database_principals AS role_principal
        ON role_principal.principal_id = membership.role_principal_id
    INNER JOIN sys.database_principals AS user_principal
        ON user_principal.principal_id = membership.member_principal_id
    WHERE role_principal.name = N'db_datareader'
      AND user_principal.name = N'$escapedLiteral'
)
    ALTER ROLE [db_datareader] ADD MEMBER [$escapedIdentifier];
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members AS membership
    INNER JOIN sys.database_principals AS role_principal
        ON role_principal.principal_id = membership.role_principal_id
    INNER JOIN sys.database_principals AS user_principal
        ON user_principal.principal_id = membership.member_principal_id
    WHERE role_principal.name = N'db_datawriter'
      AND user_principal.name = N'$escapedLiteral'
)
    ALTER ROLE [db_datawriter] ADD MEMBER [$escapedIdentifier];
"@

        Write-Host "Granting database reader/writer permissions to '$identityName' on '$databaseName'."
        Invoke-Sqlcmd `
            -ServerInstance $SqlServerFqdn `
            -Database $databaseName `
            -AccessToken $accessToken `
            -Query $query `
            -ErrorAction Stop | Out-Null
    }
}
