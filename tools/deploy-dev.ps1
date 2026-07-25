param(
    [string]$EsoAddOnsPath = "$HOME\Documents\Elder Scrolls Online\live\AddOns",
    [string]$Version
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SharedBuildScript = "D:\Dev\LUA\_GitHub\shared-tools\build-addon-dev-variant.ps1"

if (-not (Test-Path $SharedBuildScript)) {
    throw "Shared build script not found: $SharedBuildScript"
}

$Manifest = Join-Path $RepoRoot "DynamicEncounterTracker\DynamicEncounterTracker.txt"

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Match = Select-String -Path $Manifest -Pattern '^## Version:\s*(.+?)\s*$' | Select-Object -First 1
    if (-not $Match) { throw "Version not found in $Manifest" }
    $Version = $Match.Matches[0].Groups[1].Value
}

$Stage = Join-Path ([System.IO.Path]::GetTempPath()) ("DynamicEncounterTracker-dev-" + [guid]::NewGuid().ToString("N"))
& $SharedBuildScript -RepoRoot $RepoRoot -AddonName "DynamicEncounterTracker" -Version $Version -Development

$Zip = Join-Path $RepoRoot ("release\DynamicEncounterTracker_" + $Version + "-dev.zip")
Expand-Archive $Zip -DestinationPath $Stage -Force
$Target = Join-Path $EsoAddOnsPath "DynamicEncounterTracker"
if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }
Copy-Item (Join-Path $Stage "DynamicEncounterTracker") $Target -Recurse -Force
Remove-Item $Stage -Recurse -Force
Write-Host "Development variant deployed to $Target"
