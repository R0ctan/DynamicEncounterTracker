local DE = DynamicEncounterTracker
local RespawnMeasurement = {}

DE.maxRespawnMeasurements = 20
DE.defaults.respawnMeasurementEnabled = true
DE.defaults.respawnMeasurements = DE.defaults.respawnMeasurements or {}

function DE:IsRespawnMeasurementEnabled()
    return self.sv ~= nil
        and self.sv.enabled == true
        and self.sv.respawnMeasurementEnabled == true
end


local function FormatDebugDuration(seconds)
    if type(seconds) ~= "number" then
        return "-"
    end

    seconds = zo_max(0, zo_floor(seconds + 0.5))
    local hours = zo_floor(seconds / 3600)
    local minutes = zo_floor((seconds % 3600) / 60)
    local remainder = seconds % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, remainder)
    end

    return string.format("%02d:%02d", minutes, remainder)
end

function DE:EnsureMeasurementState()
    if self.state.measurement then
        self.state.measurement.runtimes = self.state.measurement.runtimes or {}
        return self.state.measurement
    end

    self.state.measurement = {
        chainId = 0,
        chainResetAt = nil,
        chainResetReason = nil,
        runtimes = {},
    }

    return self.state.measurement
end

function DE:GetEncounterMeasurementKey(config)
    return self:GetEncounterConfigKey(config)
end

function DE:EnsureSavedRespawnMeasurement(config)
    if not self.sv or not config then
        return nil
    end

    self.sv.respawnMeasurements = self.sv.respawnMeasurements or {}
    local key = self:GetEncounterMeasurementKey(config)
    if not key then
        return nil
    end

    local data = self.sv.respawnMeasurements[key]
    if type(data) ~= "table" then
        data = {}
        self.sv.respawnMeasurements[key] = data
    end

    data.key = key
    data.zoneId = config.zoneId
    data.parentWorldEventInstanceId = config.parentWorldEventInstanceId
    data.samples = type(data.samples) == "table" and data.samples or {}

    while #data.samples > self.maxRespawnMeasurements do
        table.remove(data.samples, 1)
    end

    return data
end

function DE:GetMeasurementRuntime(config, create)
    local key = self:GetEncounterMeasurementKey(config)
    if not key then
        return nil
    end

    local measurement = self:EnsureMeasurementState()
    local runtime = measurement.runtimes[key]
    if not runtime and create ~= false then
        runtime = {
            key = key,
            zoneId = config.zoneId,
            lastStartAt = nil,
            lastStartExact = false,
            lastEndAt = nil,
            lastEndExact = false,
            currentStartAt = nil,
            currentStartExact = false,
            currentStartObservedAt = nil,
            currentStartSource = nil,
            lastDeactivationObservedAt = nil,
            lastDeactivationSource = nil,
            lastEventDuration = nil,
        }
        measurement.runtimes[key] = runtime
    end
    return runtime
end

function DE:ResetMeasurementChain(reason)
    local measurement = self:EnsureMeasurementState()
    measurement.chainId = (measurement.chainId or 0) + 1
    measurement.chainResetAt = GetTimeStamp()
    measurement.chainResetReason = reason or "unspecified"
    measurement.runtimes = {}
end

function DE:AddCycleMeasurement(config, sample)
    if not self:IsRespawnMeasurementEnabled() then
        return false
    end

    local data = self:EnsureSavedRespawnMeasurement(config)
    if not data then
        return false
    end

    local measurement = self:EnsureMeasurementState()
    sample.chainId = measurement.chainId
    sample.encounterKey = data.key
    sample.zoneId = config.zoneId
    sample.recordedAt = GetTimeStamp()

    local samples = data.samples
    samples[#samples + 1] = sample
    while #samples > self.maxRespawnMeasurements do
        table.remove(samples, 1)
    end
    return true
end

function DE:RecordEncounterActivation(config, isExact, source)
    if not self:IsRespawnMeasurementEnabled() or not config then
        return
    end

    local runtime = self:GetMeasurementRuntime(config, true)
    local now = GetTimeStamp()
    local exact = isExact == true

    runtime.currentStartObservedAt = now
    runtime.currentStartSource = source or "unknown"

    if exact then
        local startToStart = nil
        local endToStart = nil

        if runtime.lastStartExact and runtime.lastStartAt then
            startToStart = now - runtime.lastStartAt
        end
        if runtime.lastEndExact and runtime.lastEndAt then
            endToStart = now - runtime.lastEndAt
        end

        if startToStart or endToStart then
            self:AddCycleMeasurement(config, {
                previousStartAt = runtime.lastStartAt,
                previousEndAt = runtime.lastEndAt,
                currentStartAt = now,
                previousEventDuration = runtime.lastEventDuration,
                startToStart = startToStart,
                endToStart = endToStart,
                startSource = source or "unknown",
            })
        end

        runtime.lastStartAt = now
        runtime.lastStartExact = true
        runtime.currentStartAt = now
        runtime.currentStartExact = true
    else
        -- Scan-detected activity has no known start; discard the open cycle.
        runtime.lastStartAt = nil
        runtime.lastStartExact = false
        runtime.currentStartAt = nil
        runtime.currentStartExact = false
    end

    -- A previous end is consumed by this start or invalidated by a missed start.
    runtime.lastEndAt = nil
    runtime.lastEndExact = false
end

function DE:RecordEncounterDeactivation(config, isExact, source)
    if not self:IsRespawnMeasurementEnabled() or not config then
        return
    end

    local runtime = self:GetMeasurementRuntime(config, true)
    local now = GetTimeStamp()
    local exact = isExact == true

    runtime.lastDeactivationObservedAt = now
    runtime.lastDeactivationSource = source or "unknown"

    if exact then
        runtime.lastEndAt = now
        runtime.lastEndExact = true
    else
        -- A periodic scan can notice that the encounter disappeared, but not
        -- determine its exact end timestamp.
        runtime.lastEndAt = nil
        runtime.lastEndExact = false
    end

    if exact and runtime.currentStartExact and runtime.currentStartAt then
        runtime.lastEventDuration = now - runtime.currentStartAt
    else
        runtime.lastEventDuration = nil
    end

    runtime.currentStartAt = nil
    runtime.currentStartExact = false
end

local function CollectMeasurementValues(samples, fieldName)
    local values = {}
    for _, sample in ipairs(samples or {}) do
        local value = sample[fieldName]
        if type(value) == "number" and value >= 0 then
            values[#values + 1] = value
        end
    end
    return values
end

local function CalculateMeasurementStats(values)
    if #values == 0 then
        return nil
    end

    local sorted = {}
    local sum = 0
    for index, value in ipairs(values) do
        sorted[index] = value
        sum = sum + value
    end
    table.sort(sorted)

    local middle = zo_floor((#sorted + 1) / 2)
    local median
    if (#sorted % 2) == 0 then
        median = (sorted[middle] + sorted[middle + 1]) / 2
    else
        median = sorted[middle]
    end

    return {
        count = #sorted,
        minimum = sorted[1],
        maximum = sorted[#sorted],
        average = sum / #sorted,
        median = median,
    }
end

local function FormatMeasurementStats(stats)
    if not stats then
        return DE:T("DE_RESPAWN_NO_VALUES")
    end
    return DE:T(
        "DE_RESPAWN_STATS",
        stats.count,
        FormatDebugDuration(stats.average),
        FormatDebugDuration(stats.median),
        FormatDebugDuration(stats.minimum),
        FormatDebugDuration(stats.maximum)
    )
end

function DE:GetRespawnMeasurementConfigsForCurrentZone()
    local configs = self.state.zoneEncounterConfigs or self:GetZoneEncounterConfigs(self.state.zoneId)
    if type(configs) ~= "table" then
        return nil
    end
    return configs
end

function DE:PrintRespawnMeasurements()
    local configs = self:GetRespawnMeasurementConfigsForCurrentZone()
    if not configs or #configs == 0 then
        self:Print(self:T("DE_RESPAWN_UNSUPPORTED"))
        return
    end

    local measurement = self:EnsureMeasurementState()
    self:Print(self:T(
        "DE_RESPAWN_HEADER",
        self:IsRespawnMeasurementEnabled() and self:T("DE_COMMON_ACTIVE") or self:T("DE_COMMON_DISABLED"),
        measurement.chainId or 0,
        tostring(measurement.chainResetReason or "-")
    ))

    for _, config in ipairs(configs) do
        local data = self:EnsureSavedRespawnMeasurement(config)
        local samples = data and data.samples or {}
        local key = self:GetEncounterMeasurementKey(config) or self:T("DE_COMMON_UNKNOWN")
        local runtime = self:GetMeasurementRuntime(config, false)

        self:Print(self:T(
            "DE_RESPAWN_ENCOUNTER_HEADER",
            self.state.zoneName ~= "" and self.state.zoneName or zo_strformat(SI_ZONE_NAME, GetZoneNameById(config.zoneId)),
            key,
            #samples,
            self.maxRespawnMeasurements
        ))
        self:Print(self:T("DE_RESPAWN_END_TO_START", FormatMeasurementStats(CalculateMeasurementStats(CollectMeasurementValues(samples, "endToStart")))))
        self:Print(self:T("DE_RESPAWN_START_TO_START", FormatMeasurementStats(CalculateMeasurementStats(CollectMeasurementValues(samples, "startToStart")))))
        self:Print(self:T("DE_RESPAWN_DURATION", FormatMeasurementStats(CalculateMeasurementStats(CollectMeasurementValues(samples, "previousEventDuration")))))

        local firstIndex = zo_max(1, #samples - 4)
        for index = firstIndex, #samples do
            local sample = samples[index]
            self:Print(self:T(
                "DE_RESPAWN_SAMPLE",
                index,
                FormatDebugDuration(sample.endToStart),
                FormatDebugDuration(sample.startToStart),
                FormatDebugDuration(sample.previousEventDuration)
            ))
        end

        if runtime then
            local statusText = self:T("DE_RESPAWN_STATE_WAIT_START")
            if runtime.currentStartExact and runtime.currentStartAt then
                statusText = self:T("DE_RESPAWN_STATE_RUNNING_EXACT")
            elseif runtime.lastEndExact and runtime.lastEndAt then
                statusText = self:T("DE_RESPAWN_STATE_WAIT_NEXT")
            elseif runtime.currentStartObservedAt then
                statusText = self:T("DE_RESPAWN_STATE_RUNNING_OBSERVED")
            end
            self:Print(self:T("DE_RESPAWN_CURRENT_STATE", statusText))
        else
            self:Print(self:T("DE_RESPAWN_CURRENT_STATE", self:T("DE_RESPAWN_STATE_NONE")))
        end
    end
end

function DE:ClearRespawnMeasurementsForCurrentZone()
    local configs = self:GetRespawnMeasurementConfigsForCurrentZone()
    if not configs or #configs == 0 then
        return false
    end

    self.sv.respawnMeasurements = self.sv.respawnMeasurements or {}
    for _, config in ipairs(configs) do
        local key = self:GetEncounterMeasurementKey(config)
        if key then
            self.sv.respawnMeasurements[key] = nil
        end
    end
    self:ResetMeasurementChain("respawn measurements cleared")
    return true
end


function DE:SetRespawnMeasurementEnabled(enabled)
    self.sv.respawnMeasurementEnabled = enabled == true
    self:ResetMeasurementChain(self.sv.respawnMeasurementEnabled and "respawn measurement enabled" or "respawn measurement disabled")

    if self.sv.respawnMeasurementEnabled
        and self:IsZoneRuntimeEnabled()
        and self.state.status == self.STATUS_ACTIVE
        and self.state.eventData then
        self:RecordEncounterActivation(
            self.state.eventData,
            false,
            "measurement enabled while encounter active"
        )
    end

    self:RefreshSettingsPanel()
end

function RespawnMeasurement:Initialize()
    DE.sv.respawnMeasurements = DE.sv.respawnMeasurements or {}
    if DE.sv.respawnMeasurementEnabled == nil then
        DE.sv.respawnMeasurementEnabled = DE.defaults.respawnMeasurementEnabled
    end
    for _, measurementData in pairs(DE.sv.respawnMeasurements) do
        if type(measurementData) == "table" then
            measurementData.samples = type(measurementData.samples) == "table" and measurementData.samples or {}
            while #measurementData.samples > DE.maxRespawnMeasurements do
                table.remove(measurementData.samples, 1)
            end
        end
    end
end

function RespawnMeasurement:ResetMeasurementChain(reason)
    return DE:ResetMeasurementChain(reason)
end

function RespawnMeasurement:RecordEncounterActivation(config, isExact, source)
    return DE:RecordEncounterActivation(config, isExact, source)
end

function RespawnMeasurement:RecordEncounterDeactivation(config, isExact, source)
    return DE:RecordEncounterDeactivation(config, isExact, source)
end

function RespawnMeasurement:HandleSlashCommand(command)
    if command == "respawn" then
        DE:PrintRespawnMeasurements()
        return true
    elseif command == "clearrespawn" then
        if DE:ClearRespawnMeasurementsForCurrentZone() then
            DE:Print(DE:T("DE_SLASH_RESPAWN_CLEARED"))
        else
            DE:Print(DE:T("DE_SLASH_RESPAWN_NONE"))
        end
        return true
    end
    return false
end

function RespawnMeasurement:PrintCommandHelp()
    DE:Print(DE:T("DE_SLASH_COMMANDS_RESPAWN"))
end

function RespawnMeasurement:AppendSettingsControls(context)
    local controls = context and context.diagnosticControls
    if type(controls) ~= "table" then
        return
    end

    controls[#controls + 1] = {
        type = "checkbox",
        name = DE:T("DE_SETTINGS_RESPAWN_ENABLED"),
        tooltip = DE:T("DE_SETTINGS_RESPAWN_ENABLED_TT"),
        default = DE.defaults.respawnMeasurementEnabled,
        getFunc = function() return DE.sv.respawnMeasurementEnabled end,
        setFunc = function(value) DE:SetRespawnMeasurementEnabled(value) end,
        disabled = context.disabledWhenOff,
        width = "full",
    }
    controls[#controls + 1] = {
        type = "description",
        text = DE:T("DE_SETTINGS_RESPAWN_DESC"),
        width = "full",
    }
    controls[#controls + 1] = {
        type = "button",
        name = DE:T("DE_SETTINGS_RESPAWN_PRINT"),
        func = function() DE:PrintRespawnMeasurements() end,
        disabled = context.disabledWhenOff,
        width = "half",
    }
    controls[#controls + 1] = {
        type = "button",
        name = DE:T("DE_SETTINGS_RESPAWN_CLEAR"),
        warning = DE:T("DE_SETTINGS_RESPAWN_CLEAR_WARN"),
        isDangerous = true,
        func = function()
            if DE:ClearRespawnMeasurementsForCurrentZone() then
                DE:Print(DE:T("DE_SLASH_RESPAWN_CLEARED"))
            else
                DE:Print(DE:T("DE_SLASH_RESPAWN_NONE"))
            end
        end,
        disabled = context.disabledWhenOff,
        width = "half",
    }
end

DE:RegisterModule("respawnMeasurement", RespawnMeasurement)
