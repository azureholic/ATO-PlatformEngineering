# Copilot Instructions — ATO-PlatformEngineering

## Repository layout

This is a **consumer / wrapper repository**. It pulls in upstream Bicep
templates as **git submodules** and only adds:

- `config/` — environment-specific overrides (`*.bicepparam`, helper scripts).
- `.github/workflows/` — CI/CD that deploys those overrides.
- Top-level docs (`prereq.md`, `README.md`, etc.).

## Submodules are READ-ONLY

The following directories are **git submodules owned by other repositories**.
**Never edit, create, delete, rename, or "fix" files inside them**, even if
they appear to have bugs, lint errors, or compile warnings:

- `bicep-ptn-aiml-landing-zone/` → upstream: `Azure/bicep-ptn-aiml-landing-zone`

Rules for the agent:

1. **Do not modify any file under a submodule path.** This includes
   formatting changes, comment tweaks, parameter additions, or "obvious"
   bug fixes. Submodule contents must stay byte-identical to the pinned
   upstream commit.
2. **Do not run `git add`, `git commit`, or any write operation against a
   submodule path.**
3. **Do not run `git submodule update`, `git submodule sync`, or change
   the pinned commit** unless the user explicitly asks to bump the
   submodule.
4. If a problem appears to originate inside a submodule (compile error,
   missing param, wrong default, etc.), **work around it from the outer
   repo** — typically by adjusting `config/main.bicepparam`, the
   workflow, or the local deploy script. If a true upstream fix is
   required, surface it to the user as something to file upstream; do
   not patch it locally.
5. When listing valid parameters, building, or running what-if/deploy,
   you **may read** submodule files (e.g. `bicep-ptn-aiml-landing-zone/main.bicep`)
   to discover declared params — reading is fine, writing is not.

## Outer repo conventions

- Customizations live in `config/` (e.g. `config/main.bicepparam`,
  `config/Deploy-Local.ps1`, `config/New-GitHubIdentity.ps1`).
- The workflow uses `workflow_dispatch` only and reads secrets from
  GitHub **Environments** (`dev`, `prod`) — not repo-scoped secrets.
- Default region is `swedencentral`.
- The `azureholic/ATO-PlatformEngineering` repo is the outer repo; the
  user runs PowerShell (pwsh) on Windows.

## When in doubt

If a requested change would touch a submodule path, **stop and ask the
user** whether the change should instead live in the outer repo (almost
always yes), or whether they want to fork/patch the submodule
explicitly.
