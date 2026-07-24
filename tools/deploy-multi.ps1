$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SharedDeployMultiScript = "D:\Dev\LUA\_GitHub\shared-tools\deploy-addon-multi.ps1"

if (-not (Test-Path $SharedDeployMultiScript)) {
    throw "Shared deploy-multi script not found: $SharedDeployMultiScript"
}

& $SharedDeployMultiScript `
    -RepoRoot $RepoRoot `
    -AddonName "DynamicEncounterTracker"

