<#
.SYNOPSIS
    Starts the Catalog MCP server and the Chat Agent locally.

.DESCRIPTION
    Launches the MCP server in a separate PowerShell window, waits until it
    responds on /healthz, then runs the chat agent in the current console.
    Closing the chat agent leaves the MCP server window open so you can
    inspect logs; close that window manually to stop it.
#>

[CmdletBinding()]
param(
    [string]$McpUrl = 'http://localhost:5000',
    [int]$StartupTimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$mcpDir   = Join-Path $root 'mcp-server\src'
$agentDir = Join-Path $root 'chat-agent'

Write-Host "Starting MCP server ($mcpDir) ..." -ForegroundColor Cyan
$mcpProcess = Start-Process -FilePath 'pwsh' `
    -ArgumentList @(
        '-NoExit',
        '-Command',
        "Set-Location '$mcpDir'; `$env:ASPNETCORE_URLS='$McpUrl'; dotnet run"
    ) `
    -PassThru

Write-Host "Waiting for MCP server at $McpUrl/healthz ..." -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri "$McpUrl/healthz" -UseBasicParsing -TimeoutSec 2
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch { Start-Sleep -Milliseconds 500 }
}
if (-not $ready) {
    Write-Warning "MCP server did not respond within $StartupTimeoutSeconds s; starting agent anyway."
}

Write-Host "Starting Chat Agent ($agentDir) ..." -ForegroundColor Cyan
Push-Location $agentDir
try {
    $env:Mcp__Endpoint = "$McpUrl/mcp"
    dotnet run
}
finally {
    Pop-Location
    Write-Host "Agent exited. MCP server (PID $($mcpProcess.Id)) is still running in its own window." -ForegroundColor Yellow
}
