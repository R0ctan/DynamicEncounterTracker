$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SharedScript = "D:\Dev\LUA\_GitHub\shared-tools\validate-addon.ps1"

if (-not (Test-Path $SharedScript)) {
    throw "Shared validate script not found: $SharedScript"
}

& $SharedScript `
    -RepoRoot $RepoRoot `
    -AddonName "DynamicEncounterTracker"

