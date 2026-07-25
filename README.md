# Dynamic Encounter Tracker

Dynamic Encounter Tracker is an ESO addon by R0ctan that tracks configured Dynamic Encounters, their current localized objective, participation state, configured reward-chest moments, and an estimated respawn window.

## Features

- Detects configured Dynamic Encounters in Stonefalls, Glenumbra, and Auridon
- Shows the localized encounter and step text supplied by ESO
- Displays the known step position, current objective progress, and remembered participation state
- Wraps long localized section and hint text and adjusts the status-window height dynamically
- Shows chest notifications only for explicit encounter-specific rules
- Provides a separate movable and customizable chest alert window
- Shows a per-encounter cooldown, spawn window and overdue counter after a detected event end
- Lets users override earliest and expected respawn times per encounter in `MM:SS` format
- Suspends encounter polling and processing outside configured zones
- Supports multiple encounter configurations per zone
- Includes optional development-only debug and respawn-measurement modules that are excluded from the production package

## Configured Encounters

- Stonefalls: 11-step sequence, 3 configured chest rules
- Glenumbra: 13-step sequence, 3 configured chest rules
- Auridon: 5-step sequence, 2 configured chest rules

Default respawn timings are based on repeated live measurements and are stored separately per encounter:

- Stonefalls: earliest `30:00`, expected `33:00`
- Glenumbra: earliest `30:00`, expected `30:11`
- Auridon: earliest `30:00`, expected `31:02`

The production addon shows a normal cooldown until the earliest time, then a spawn window until the expected time, and afterwards an upward-counting overrun until the encounter is detected. Users can override both values per encounter in the settings.

## Supported Languages

- English
- German
- French
- Spanish
- Russian
- Simplified Chinese

English is the base language. German overrides are fully translated. French, Spanish, Russian, and Simplified Chinese files exist with the complete key set but currently hold English placeholder text pending real translation. Encounter names and objectives are never hard-coded; they are read from ESO in the active game language.

## Requirements

This addon requires:

- LibAddonMenu-2.0 r43 or newer

Please install and enable LibAddonMenu-2.0 before using this addon.

## Installation

Download the addon ZIP file and extract it into your ESO AddOns folder:

```text
Documents\Elder Scrolls Online\live\AddOns\
```

The final folder should look like this:

```text
Documents\Elder Scrolls Online\live\AddOns\DynamicEncounterTracker\
```

Inside that folder, `DynamicEncounterTracker.txt` must be directly visible.

## Slash Commands

Production:

- `/dynet on`
- `/dynet off`
- `/dynet show`
- `/dynet hide`

The development package additionally provides `/dynet respawn`, `/dynet clearrespawn`, debug, history, and alert-test commands.

## Development

Local development uses shared NextTry tooling:

```powershell
.\tools\validate.ps1
.\tools\build.ps1
.\tools\deploy.ps1
```

Production and development ZIP variants:

```powershell
.\tools\build-all.ps1
.\tools\build-dev.ps1
.\tools\deploy-dev.ps1
```

Release preparation:

```powershell
.\tools\release.ps1 -Version 1.0.0
```

## Author

Created by R0ctan.

AI-assisted development by Auralith AI.

## License

This project is licensed under the MIT License.
