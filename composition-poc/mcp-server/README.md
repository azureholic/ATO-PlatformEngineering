# Catalog MCP Server

A .NET 10 MCP server packaged for `azd up` to Azure Container Apps. It exposes
the catalog from a separate repository (default: `azureholic/ATO-Catalog`)
as MCP tools.

## Layout

```
mcp-server/
  azure.yaml           # azd service: api → container app
  infra/               # Bicep (subscription scope) — Log Analytics, ACR, ACA env, container app
  src/                 # .NET 10 source + Dockerfile
```

## Catalog source

Configured via the `Catalog` configuration section (env vars use `__` separators):

| Setting                       | Default                          |
| ----------------------------- | -------------------------------- |
| `Catalog__Source`             | `GitHub` (or `Local`)            |
| `Catalog__GitHub__Owner`      | `azureholic`                     |
| `Catalog__GitHub__Repo`       | `ATO-Catalog`                    |
| `Catalog__GitHub__Branch`     | `main`                           |
| `Catalog__GitHub__Path`       | `` (repo root)                   |
| `Catalog__GitHub__Token`      | _(optional PAT for rate limits)_ |
| `Catalog__LocalPath`          | `<basedir>/catalog` (Local only) |

Default points at <https://github.com/azureholic/ATO-Catalog>.

## Endpoints

- `GET /` — metadata + active source
- `GET /healthz` — liveness
- `POST /mcp` — MCP Streamable HTTP

## MCP tools

- `list_catalog_items` — returns every catalog item with parsed manifest
- `get_catalog_item(id)` — returns one catalog item by folder name

## Local run

```pwsh
cd composition-poc/mcp-server/src
dotnet run
```

## Deploy

```pwsh
cd composition-poc/mcp-server
azd auth login
azd up
```
