# Custom Deployment Configuration

This folder holds your environment-specific Bicep parameters that override the defaults
shipped with the [`bicep-ptn-aiml-landing-zone`](../bicep-ptn-aiml-landing-zone/) submodule.

## Files

- [`main.bicepparam`](main.bicepparam) — typed Bicep parameter file. Uses
  `using '../bicep-ptn-aiml-landing-zone/main.bicep'` so it is bound to the submodule's
  template and validated by the Bicep CLI.

## Why `.bicepparam` instead of editing the submodule's `main.parameters.json`?

- The submodule is tracked separately; editing files inside it creates merge conflicts on update.
- `.bicepparam` is type-checked against the template (catches typos in parameter names).
- Values can be sourced from environment variables via `readEnvironmentVariable(...)`,
  which works well with CI/CD.

## Local deployment

Target scope is **resource group** (`targetScope = 'resourceGroup'` in `main.bicep`):

```pwsh
$env:AZURE_ENV_NAME      = 'dev'
$env:AZURE_LOCATION      = 'eastus2'
$env:AZURE_PRINCIPAL_ID  = (az ad signed-in-user show --query id -o tsv)

az group create --name "rg-ai-lz-$env:AZURE_ENV_NAME" --location $env:AZURE_LOCATION

az deployment group create `
  --resource-group   "rg-ai-lz-$env:AZURE_ENV_NAME" `
  --template-file    ../bicep-ptn-aiml-landing-zone/main.bicep `
  --parameters       ./main.bicepparam
```

To preview changes without deploying:

```pwsh
az deployment group what-if `
  --resource-group   "rg-ai-lz-$env:AZURE_ENV_NAME" `
  --template-file    ../bicep-ptn-aiml-landing-zone/main.bicep `
  --parameters       ./main.bicepparam
```

## CI/CD

The workflow [`.github/workflows/deploy-bicep.yml`](../.github/workflows/deploy-bicep.yml)
uses this file automatically. See [`prereq.md`](../prereq.md) for required secrets.

## Customizing

Edit [`main.bicepparam`](main.bicepparam) and either:

1. **Hardcode values** (replace the `readEnvironmentVariable(...)` calls), or
2. **Set env vars** before running `az deployment` / before the workflow runs.

Common env vars consumed by the parameter file:

| Variable | Purpose | Default |
| --- | --- | --- |
| `AZURE_ENV_NAME` | Environment name (used in resource naming) | `dev` |
| `AZURE_LOCATION` | Primary region | `eastus2` |
| `AZURE_PRINCIPAL_ID` | Object ID for RBAC assignments | _(empty — required)_ |
| `NETWORK_ISOLATION` | Enable private endpoints / network isolation | `true` |
| `DEPLOY_AZURE_FIREWALL` | Provision Azure Firewall | `false` |
| `DEPLOY_VM` | Provision jumpbox VM | `false` |
| `DEPLOY_SPEECH_SERVICE` | Provision Azure AI Speech | `false` |
| `USE_UAI` | Use User-Assigned Managed Identity | `true` |
| `VM_ADMIN_PASSWORD` | Required when `DEPLOY_VM=true` | _(empty)_ |
