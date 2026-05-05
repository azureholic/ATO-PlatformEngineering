<#
.SYNOPSIS
    Deploy the AI Landing Zone Bicep submodule from your local machine using
    the customized config/main.bicepparam.

.DESCRIPTION
    Mirrors the GitHub Actions workflow (.github/workflows/deploy-bicep.yml):
      1. Sets AZURE_ENV_NAME / AZURE_LOCATION / AZURE_PRINCIPAL_ID env vars
         (consumed by main.bicepparam via readEnvironmentVariable).
      2. Ensures the target resource group exists.
      3. Builds the Bicep template.
      4. Runs what-if (always) and then a deployment (unless -WhatIfOnly).

    Requires:
      - Azure CLI logged in (`az login`) with the right subscription selected.
      - Bicep installed (`az bicep install`).
      - The submodule checked out at ../bicep-ptn-aiml-landing-zone.

.PARAMETER EnvironmentName
    azd-style environment name; also used as resource name prefix.

.PARAMETER Location
    Primary Azure region. Defaults to swedencentral.

.PARAMETER ResourceGroupName
    Target resource group. Defaults to rg-ai-lz-<EnvironmentName>.

.PARAMETER SubscriptionId
    Subscription to deploy into. Defaults to current az context.

.PARAMETER PrincipalId
    Object ID of the user/SP that should receive data-plane RBAC.
    Defaults to the signed-in user's object id.

.PARAMETER WhatIfOnly
    If set, only runs `az deployment group what-if` and skips the actual deploy.

.EXAMPLE
    ./config/Deploy-Local.ps1 -EnvironmentName dev

.EXAMPLE
    ./config/Deploy-Local.ps1 -EnvironmentName dev -WhatIfOnly
#>
[CmdletBinding()]
param(
    [string] $EnvironmentName    = 'dev',
    [string] $Location           = 'swedencentral',
    [string] $ResourceGroupName,
    [string] $SubscriptionId,
    [string] $PrincipalId,
    [switch] $WhatIfOnly
)

$ErrorActionPreference = 'Stop'

# Resolve repo root and key paths regardless of where the script is invoked from
$repoRoot      = Resolve-Path (Join-Path $PSScriptRoot '..')
$templateFile  = Join-Path $repoRoot 'bicep-ptn-aiml-landing-zone/main.bicep'
$parameterFile = Join-Path $PSScriptRoot 'main.bicepparam'

if (-not (Test-Path $templateFile)) {
    throw "Template not found at $templateFile. Did you initialize the submodule? Try: git submodule update --init --recursive"
}
if (-not (Test-Path $parameterFile)) {
    throw "Parameter file not found at $parameterFile."
}

# Verify az CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') not found in PATH."
}

# Ensure logged in
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Not logged in to Azure CLI. Run 'az login' first."
}

# Switch subscription if requested
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId | Out-Null
    $account = az account show | ConvertFrom-Json
}

# Resolve principal id (signed-in user) if not provided
if (-not $PrincipalId) {
    $PrincipalId = az ad signed-in-user show --query id -o tsv 2>$null
    if (-not $PrincipalId) {
        Write-Warning "Could not resolve signed-in user object id. Pass -PrincipalId explicitly if data-plane role assignments are needed."
        $PrincipalId = ''
    }
}

# Default RG name
if (-not $ResourceGroupName) {
    $ResourceGroupName = "rg-ai-lz-$EnvironmentName"
}

Write-Host ""
Write-Host "Deployment context" -ForegroundColor Cyan
Write-Host "  Subscription : $($account.name) ($($account.id))" -ForegroundColor Green
Write-Host "  Tenant       : $($account.tenantId)"               -ForegroundColor Green
Write-Host "  EnvName      : $EnvironmentName"                    -ForegroundColor Green
Write-Host "  Location     : $Location"                           -ForegroundColor Green
Write-Host "  ResourceGrp  : $ResourceGroupName"                  -ForegroundColor Green
Write-Host "  PrincipalId  : $PrincipalId"                        -ForegroundColor Green
Write-Host "  Template     : $templateFile"                       -ForegroundColor Green
Write-Host "  Parameters   : $parameterFile"                      -ForegroundColor Green
Write-Host "  WhatIfOnly   : $WhatIfOnly"                         -ForegroundColor Green
Write-Host ""

# Export env vars consumed by main.bicepparam
$env:AZURE_ENV_NAME     = $EnvironmentName
$env:AZURE_LOCATION     = $Location
$env:AZURE_PRINCIPAL_ID = $PrincipalId

# Ensure resource group
Write-Host "Ensuring resource group '$ResourceGroupName' exists..." -ForegroundColor Cyan
az group create `
    --name $ResourceGroupName `
    --location $Location `
    --tags environment=$EnvironmentName managedBy=bicep `
    --output none

# Bicep build (validates syntax/types)
Write-Host "Building Bicep template..." -ForegroundColor Cyan
az bicep build --file $templateFile

# What-if
$deploymentName = "$EnvironmentName-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "Running what-if as deployment '$deploymentName'..." -ForegroundColor Cyan
az deployment group what-if `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $templateFile `
    --parameters $parameterFile

if ($WhatIfOnly) {
    Write-Host ""
    Write-Host "WhatIfOnly: skipping actual deployment." -ForegroundColor Yellow
    return
}

# Deploy
Write-Host "Starting deployment '$deploymentName'..." -ForegroundColor Cyan
az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file $templateFile `
    --parameters $parameterFile

Write-Host ""
Write-Host "Deployment '$deploymentName' submitted to '$ResourceGroupName'." -ForegroundColor Green
