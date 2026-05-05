<#
.SYNOPSIS
    Creates a resource group and a User-Assigned Managed Identity (UAMI) used by
    the GitHub Actions workflow to deploy the AI Landing Zone via OIDC.

.DESCRIPTION
    Uses the currently logged-in Azure CLI session (run `az login` first).
    Creates:
      - Resource group: rg-github-identity
      - UAMI:           id-github-actions-ai-lz

    Outputs the values needed for GitHub repository secrets:
      AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, AZURE_PRINCIPAL_ID

.NOTES
    By default, secrets are uploaded to GitHub via `gh` CLI. Use
    -SkipGitHubSecrets to only print them. Requires `gh auth login`.
#>

[CmdletBinding()]
param(
    [string]   $Location = 'swedencentral',
    [string[]] $Environments = @('dev','prod'),
    [switch]   $SkipGitHubSecrets
)

$ErrorActionPreference = 'Stop'

$resourceGroupName = 'rg-github-identity'
$identityName      = 'id-github-actions-ai-lz'
$roles             = @('Contributor', 'User Access Administrator')

# --- Detect GitHub repo + branch from local git ------------------------------
Write-Host 'Detecting GitHub repository from local git...' -ForegroundColor Cyan
$remoteUrl = git config --get remote.origin.url 2>$null
if (-not $remoteUrl) { throw 'Could not read remote.origin.url. Run this from inside the git repo.' }

# Match both https and ssh forms: https://github.com/<owner>/<repo>(.git)? or git@github.com:<owner>/<repo>(.git)?
if ($remoteUrl -notmatch 'github\.com[:/]([^/]+)/([^/.]+?)(?:\.git)?/?$') {
    throw "remote.origin.url '$remoteUrl' is not a recognized GitHub URL."
}
$GitHubOwner = $Matches[1]
$GitHubRepo  = $Matches[2]

$Branch = git rev-parse --abbrev-ref HEAD 2>$null
if (-not $Branch -or $Branch -eq 'HEAD') { $Branch = 'main' }

Write-Host "Repo   : $GitHubOwner/$GitHubRepo" -ForegroundColor Green
Write-Host "Branch : $Branch" -ForegroundColor Green

# --- Verify az CLI session ----------------------------------------------------
Write-Host 'Checking Azure CLI login...' -ForegroundColor Cyan
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    throw 'Not logged in. Run `az login` first.'
}

$subscriptionId = $account.id
$tenantId       = $account.tenantId
Write-Host "Subscription : $($account.name) ($subscriptionId)" -ForegroundColor Green
Write-Host "Tenant       : $tenantId" -ForegroundColor Green

# --- Resource group -----------------------------------------------------------
Write-Host "`nEnsuring resource group '$resourceGroupName' in '$location'..." -ForegroundColor Cyan
az group create `
    --name $resourceGroupName `
    --location $location `
    --tags purpose=github-oidc managedBy=script `
    --output none

# --- User-Assigned Managed Identity ------------------------------------------
Write-Host "Ensuring UAMI '$identityName'..." -ForegroundColor Cyan
$uami = az identity create `
    --name $identityName `
    --resource-group $resourceGroupName `
    --location $location `
    --output json | ConvertFrom-Json

$clientId   = $uami.clientId
$principalId = $uami.principalId

# --- Federated credentials ----------------------------------------------------
$issuer   = 'https://token.actions.githubusercontent.com'
$audience = @('api://AzureADTokenExchange')

$subjects = @(
    @{ Name = "github-$GitHubRepo-branch-$Branch"; Subject = "repo:$GitHubOwner/$GitHubRepo`:ref:refs/heads/$Branch" }
    @{ Name = "github-$GitHubRepo-pull-request";   Subject = "repo:$GitHubOwner/$GitHubRepo`:pull_request" }
)
foreach ($env in $Environments) {
    $subjects += @{
        Name    = "github-$GitHubRepo-env-$env"
        Subject = "repo:$GitHubOwner/$GitHubRepo`:environment:$env"
    }
}

Write-Host "`nConfiguring federated credentials on '$identityName'..." -ForegroundColor Cyan
$existing = az identity federated-credential list `
    --identity-name $identityName `
    --resource-group $resourceGroupName `
    --output json | ConvertFrom-Json

foreach ($fc in $subjects) {
    if ($existing | Where-Object { $_.name -eq $fc.Name }) {
        Write-Host "  - $($fc.Name) already exists, skipping." -ForegroundColor DarkGray
        continue
    }
    Write-Host "  + Creating $($fc.Name) -> $($fc.Subject)" -ForegroundColor Green
    az identity federated-credential create `
        --name $fc.Name `
        --identity-name $identityName `
        --resource-group $resourceGroupName `
        --issuer $issuer `
        --subject $fc.Subject `
        --audiences $audience `
        --output none
}

# --- Role assignments ---------------------------------------------------------
$scope = "/subscriptions/$subscriptionId"
Write-Host "`nAssigning roles to UAMI on subscription scope..." -ForegroundColor Cyan

# Wait briefly for AAD propagation of the new principal
$maxAttempts = 12
for ($i = 1; $i -le $maxAttempts; $i++) {
    az ad sp show --id $principalId --output none 2>$null
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "  ...waiting for principal $principalId to propagate ($i/$maxAttempts)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
}

foreach ($role in $roles) {
    $existing = az role assignment list `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role $role `
        --scope $scope `
        --output json | ConvertFrom-Json

    if ($existing) {
        Write-Host "  - '$role' already assigned, skipping." -ForegroundColor DarkGray
        continue
    }

    Write-Host "  + Assigning '$role' at $scope" -ForegroundColor Green
    az role assignment create `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role $role `
        --scope $scope `
        --output none
}

# --- Output -------------------------------------------------------------------
Write-Host "`n=== GitHub Actions Secrets ===" -ForegroundColor Yellow
Write-Host "AZURE_CLIENT_ID       = $clientId"
Write-Host "AZURE_TENANT_ID       = $tenantId"
Write-Host "AZURE_SUBSCRIPTION_ID = $subscriptionId"
Write-Host "AZURE_PRINCIPAL_ID    = $principalId"
Write-Host "==============================`n" -ForegroundColor Yellow

# --- Upload secrets via gh CLI -----------------------------------------------
if (-not $SkipGitHubSecrets) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning "gh CLI not found. Install from https://cli.github.com or rerun with -SkipGitHubSecrets."
    }
    else {
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "gh CLI is not authenticated. Run 'gh auth login' first or rerun with -SkipGitHubSecrets."
            Write-Warning $authStatus
        }
        else {
            $repoSlug = "$GitHubOwner/$GitHubRepo"
            $secrets = @{
                AZURE_CLIENT_ID       = $clientId
                AZURE_TENANT_ID       = $tenantId
                AZURE_SUBSCRIPTION_ID = $subscriptionId
                AZURE_PRINCIPAL_ID    = $principalId
            }

            Write-Host "Setting repository secrets on $repoSlug..." -ForegroundColor Cyan
            foreach ($name in $secrets.Keys) {
                Write-Host "  + $name" -ForegroundColor Green
                $secrets[$name] | gh secret set $name --repo $repoSlug --body -
            }

            foreach ($env in $Environments) {
                Write-Host "Setting environment secrets on $repoSlug / $env..." -ForegroundColor Cyan
                # Ensure environment exists (idempotent via REST)
                gh api --method PUT "repos/$repoSlug/environments/$env" --silent 2>$null | Out-Null
                foreach ($name in $secrets.Keys) {
                    Write-Host "  + $name -> $env" -ForegroundColor Green
                    $secrets[$name] | gh secret set $name --repo $repoSlug --env $env --body -
                }
            }
        }
    }
}

[pscustomobject]@{
    AZURE_CLIENT_ID       = $clientId
    AZURE_TENANT_ID       = $tenantId
    AZURE_SUBSCRIPTION_ID = $subscriptionId
    AZURE_PRINCIPAL_ID    = $principalId
}
