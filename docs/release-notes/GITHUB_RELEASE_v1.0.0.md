# Dynamic Encounter Tracker 1.0.0

Initial public release, migrated from the earlier Dynamic Encounter addon (renamed to Dynamic Encounter Tracker / `/dynet`; no functional changes to encounter logic, chest rules, or respawn timing).

## Features

- Tracks configured Dynamic Encounters in Stonefalls, Glenumbra, and Auridon
- Shows the localized encounter name and step text supplied directly by ESO
- Displays the known step position, current objective progress, and remembered participation state
- Chest notifications only for explicit, tested per-encounter rules, with a separate movable and customizable chest alert window
- Per-encounter cooldown, spawn window, and overdue counter after a detected encounter end, with adjustable earliest/expected respawn times per encounter
- Suspends encounter polling outside configured zones
- Optional development-only debug and respawn-measurement modules, excluded from the production package

## Localization

Full key set in English, German, French, Spanish, Russian, and Simplified Chinese. German is fully reviewed; the other four are complete machine translations pending a native-speaker review.

## Requirements

- LibAddonMenu-2.0 r43 or newer

## Notes

AI-assisted development by Auralith AI.
