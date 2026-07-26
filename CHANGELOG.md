# Changelog

All notable changes to Dynamic Encounter Tracker are documented here.

## 1.1.0

- Added an optional minimal mode for the status window: a compact single-line display (with an extra line once participation is confirmed) instead of the full window, with a toggle button next to the close button
- Window width and height in minimal mode adjust automatically to the current text
- Added independent settings to show or hide the close button and the minimal-mode toggle button
- Fixed redundant internal panel refresh calls in the settings window (thanks to Baertram for the report)

## 1.0.0 — Initial release

- Detects configured Dynamic Encounters in Stonefalls, Glenumbra, and Auridon
- Shows the localized encounter and step text supplied by ESO
- Displays the known step position, current objective progress, and remembered participation state
- Shows chest notifications only for explicit encounter-specific rules
- Provides a separate movable and customizable chest alert window
- Shows a per-encounter cooldown, spawn window and overdue counter after a detected event end
- Lets users override earliest and expected respawn times per encounter in `MM:SS` format
- Suspends encounter polling and processing outside configured zones
- Available in English, German, French, Spanish, Russian, and Simplified Chinese
