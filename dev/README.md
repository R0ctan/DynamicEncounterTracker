# Development modules

`DynamicEncounterTracker_RespawnMeasurement.lua` contains optional respawn measurement samples, statistics, settings and `/dynet respawn` / `/dynet clearrespawn`.

`DynamicEncounterTracker_Debug.lua` contains optional diagnostics, step-learning history, API dumps, debug status rows, debug settings and test commands.

Neither file is part of the production addon folder and neither may be referenced by the production manifest. The normal respawn timer, spawn window, overdue display and user timer settings remain production functionality in `DynamicEncounterTracker_Respawn.lua`.

`DynamicEncounterTracker.dev.txt` is copied over the production manifest only while staging the development ZIP.
