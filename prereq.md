# Prerequisites — Deploy Bicep Submodule Workflow

The workflow [.github/workflows/deploy-bicep.yml](.github/workflows/deploy-bicep.yml) deploys the
`bicep-ptn-aiml-landing-zone` submodule to Azure. Before running it, configure the items below.

## Required GitHub Secrets

Add these as repository secrets (Settings → Secrets and variables → Actions), or scope them to a
GitHub Environment matching your `environmentName` input (e.g. `dev`, `prod`):

| Secret | Description |
| --- | --- |
| `AZURE_CLIENT_ID` | Client (application) ID of the Entra ID app registration or user-assigned managed identity used for OIDC federated authentication. |
| `AZURE_TENANT_ID` | Entra ID tenant ID. |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID where the landing zone is deployed. |
| `AZURE_PRINCIPAL_ID` | Object ID of the principal that should receive role assignments created by the template (passed as the `principalId` parameter). |

## Federated Credential (OIDC)

The workflow uses [`azure/login@v2`](https://github.com/Azure/login) with OIDC — no client secret
is stored. On the app registration / managed identity referenced by `AZURE_CLIENT_ID`, add a
federated credential with:

- **Issuer:** `https://token.actions.githubusercontent.com`
- **Subject:** `repo:<owner>/<repo>:ref:refs/heads/main`
  - For environment-scoped runs: `repo:<owner>/<repo>:environment:<environmentName>`
- **Audience:** `api://AzureADTokenExchange`

## Azure RBAC

The principal referenced by `AZURE_CLIENT_ID` must have permissions to deploy at **subscription
scope** and to create the resources defined in `main.bicep`. Typical minimum:

- `Owner` or `Contributor` + `User Access Administrator` on the target subscription
  (required because the template performs role assignments).

## Resource Providers

Ensure the following providers are registered in the target subscription (the deployment will
fail if any are missing):

- `Microsoft.CognitiveServices`
- `Microsoft.MachineLearningServices`
- `Microsoft.Search`
- `Microsoft.DocumentDB`
- `Microsoft.Storage`
- `Microsoft.KeyVault`
- `Microsoft.Network`
- `Microsoft.App`
- `Microsoft.ContainerRegistry`
- `Microsoft.Insights`
- `Microsoft.OperationalInsights`
- `Microsoft.AppConfiguration`

Register with:

```bash
az provider register --namespace <namespace>
```

## GitHub Environment (optional but recommended)

Create environments named after each `environmentName` input value (e.g. `dev`, `prod`) so you can:

- Require manual approval before the `deploy` job runs.
- Scope secrets per environment.
- Restrict which branches can deploy.

## Workflow Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `environmentName` | `dev` | Used as `AZURE_ENV_NAME` and as the GitHub environment name. |
| `location` | `eastus2` | Primary Azure region. |
| `whatIf` | `false` | When `true`, the deploy job is skipped and only `what-if` runs. |
