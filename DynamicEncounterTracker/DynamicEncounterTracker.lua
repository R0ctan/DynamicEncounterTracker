local ADDON_NAME = "DynamicEncounterTracker"
local Addon = {}
_G[ADDON_NAME] = Addon

Addon.name = ADDON_NAME
Addon.displayName = "Dynamic Encounter Tracker"
Addon.version = "1.0.0"

local function Print(message)
    if NextTryShared and NextTryShared.Chat and NextTryShared.Chat.Print then
        if NextTryShared.Chat.Print(Addon.displayName, message, "84E291") then
            return
        end
    end

    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", Addon.displayName, message))
    elseif d then
        d(string.format("[%s] %s", Addon.displayName, message))
    end
end

function Addon.OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    Print(GetString(DYNAMICENCOUNTERTRACKER_READY))
end

function Addon.OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    Addon.db = ZO_SavedVars:NewAccountWide("DynamicEncounterTracker_Data", 1, nil, DEFAULTS, GetWorldName())

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, Addon.OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, Addon.OnAddOnLoaded)

