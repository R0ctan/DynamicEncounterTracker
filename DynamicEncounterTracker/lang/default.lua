DynamicEncounterTracker = DynamicEncounterTracker or {}
DynamicEncounterTracker.Strings = DynamicEncounterTracker.Strings or {}

local function AddString(key, value)
    local stringId = "DYNAMICENCOUNTERTRACKER_" .. key
    if ZO_CreateStringId then
        ZO_CreateStringId(stringId, value)
    end
    local id = _G[stringId]
    if id and SafeAddVersion then
        SafeAddVersion(id, 1)
    end
    DynamicEncounterTracker.Strings[key] = id
end

AddString("addonName", "Dynamic Encounter Tracker")
AddString("ready", "Ready.")

