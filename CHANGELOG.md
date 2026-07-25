# Changelog

All notable changes to Dynamic Encounter Tracker are documented here.

## 1.0.0

- Renamed the project from Dynamic Encounter to Dynamic Encounter Tracker (short form `DynET`, slash command `/dynet`)
- Migrated the complete Dynamic Encounter 0.1.23 feature set into the new repository and addon namespace
- Detects configured Dynamic Encounters in Stonefalls, Glenumbra, and Auridon
- Shows the localized encounter and step text supplied by ESO
- Displays the known step position, current objective progress, and remembered participation state
- Shows chest notifications only for explicit encounter-specific rules
- Provides a separate movable and customizable chest alert window
- Shows a per-encounter cooldown, spawn window and overdue counter after a detected event end
- Lets users override earliest and expected respawn times per encounter in `MM:SS` format
- Suspends encounter polling and processing outside configured zones
- Keeps optional development-only debug and respawn-measurement modules excluded from the production package

### Technical

- Uses the shared NextTry repository structure and shared NextTry tooling for validation, build, deploy and release
- Requires `LibAddonMenu-2.0>=43`
- Retains the production/development build-variant split (`tools/build-all.ps1`, `tools/build-dev.ps1`, `tools/deploy-dev.ps1`) alongside the standard shared-tools scripts
