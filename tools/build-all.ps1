param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SharedScript = "D:\Dev\LUA\_GitHub\shared-tools\build-addon-dev-variant.ps1"

if (-not (Test-Path $SharedScript)) {
    throw "Shared build script not found: $SharedScript"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Manifest = Join-Path $RepoRoot "DynamicEncounterTracker\DynamicEncounterTracker.txt"
    $Match = Select-String -Path $Manifest -Pattern '^## Version:\s*(.+?)\s*$' | Select-Object -First 1
    if (-not $Match) { throw "Version not found in $Manifest" }
    $Version = $Match.Matches[0].Groups[1].Value
}

& $SharedScript -RepoRoot $RepoRoot -AddonName "DynamicEncounterTracker" -Version $Version
& $SharedScript -RepoRoot $RepoRoot -AddonName "DynamicEncounterTracker" -Version $Version -Development
