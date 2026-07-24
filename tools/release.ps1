param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [switch]$CreateTag,

    [Parameter(Mandatory = $false)]
    [switch]$Push
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SharedReleaseScript = "D:\Dev\LUA\_GitHub\shared-tools\release-addon.ps1"

if (-not (Test-Path $SharedReleaseScript)) {
    throw "Shared release script not found: $SharedReleaseScript"
}

& $SharedReleaseScript `
    -RepoRoot $RepoRoot `
    -AddonName "DynamicEncounterTracker" `
    -Version $Version `
    -CreateTag:$CreateTag `
    -Push:$Push

