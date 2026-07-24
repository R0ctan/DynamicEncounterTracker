---@diagnostic disable: undefined-global

DynamicEncounterTracker = DynamicEncounterTracker or {}
DynamicEncounterTracker.Strings = DynamicEncounterTracker.Strings or {}

local function AddString(key, value)
    local stringId = "DYNAMICENCOUNTERTRACKER_" .. key
    local id = _G[stringId]
    if id and SafeAddString then
        SafeAddString(id, value, 2)
    end
end

AddString("addonName", "Dynamic Encounter Tracker")
AddString("ready", "Готово.")

