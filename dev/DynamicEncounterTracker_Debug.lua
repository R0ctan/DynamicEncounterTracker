local DE = DynamicEncounterTracker
local WM = WINDOW_MANAGER
local Debug = {}

DE.defaults.stepLearning = DE.defaults.stepLearning or {}
DE.defaults.diagnosticHistory = DE.defaults.diagnosticHistory or {}

local function WorldEventInstanceIterator(_, lastWorldEventInstanceId)
    return GetNextWorldEventInstanceId(lastWorldEventInstanceId)
end

local WORLD_EVENT_TYPE_NAMES = {
    [WORLD_EVENT_TYPE_MONSTER_HUNT] = "MONSTER_HUNT",
    [WORLD_EVENT_TYPE_SCRIPTED_EVENT] = "SCRIPTED_EVENT",
    [WORLD_EVENT_TYPE_STATIC_MONSTER] = "STATIC_MONSTER",
}

local WORLD_EVENT_LOCATION_CONTEXT_NAMES = {
    [WORLD_EVENT_LOCATION_CONTEXT_UNIT] = "UNIT",
    [WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST] = "POINT_OF_INTEREST",
}

local function DebugBool(value)
    if value == nil then
        return "-"
    end
    return value and "true" or "false"
end

local function DebugText(value)
    if value == nil or value == "" then
        return "-"
    end
    return tostring(value)
end

local function DebugNumber(value, decimals)
    if type(value) ~= "number" then
        return "-"
    end

    if decimals then
        return string.format("%." .. tostring(decimals) .. "f", value)
    end

    return tostring(value)
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


function DE:EnsureDiagnosticHistory()
    self.sv.diagnosticHistory = self.sv.diagnosticHistory or {}
    return self.sv.diagnosticHistory
end

function DE:BuildDiagnosticSignature()
    return table.concat({
        tostring(self.state.zoneId or 0),
        tostring(self.state.status or "-"),
        tostring(self.state.activeWorldEventInstanceId or 0),
        tostring(self.state.activeWorldEventRole or "-"),
        tostring(self.state.parentActive == true),
        tostring(self.state.eventName or "-"),
        tostring(self.state.phaseName or "-"),
        tostring(self.state.currentStepDefId or 0),
        tostring(self.state.currentMapLocationIndex or 0),
        tostring(self.state.isParticipating == true),
        tostring(self.state.currentProgress ~= nil and self.state.currentProgress or "-"),
        tostring(self.state.maxProgress ~= nil and self.state.maxProgress or "-"),
        tostring(self.state.currentStepOrdinal or 0),
        tostring(self.state.currentStepTotal or 0),
        tostring(self.state.chestCandidateCount or 0),
        tostring(self.state.lastChestRuleId or "-"),
        tostring(self:GetParticipatedStepListText()),
        tostring(self.state.chestHintText or "-"),
    }, "|")
end

function DE:_DebugRecordDiagnosticSnapshot(source, force)
    if not self:IsDebugEnabled() then
        return
    end

    local signature = self:BuildDiagnosticSignature()
    if not force and signature == self.state.lastDiagnosticSignature then
        return
    end
    self.state.lastDiagnosticSignature = signature

    local history = self:EnsureDiagnosticHistory()
    history[#history + 1] = {
        timestamp = GetTimeStamp(),
        source = source or "unknown",
        runId = self.state.encounterRunId or 0,
        zoneId = self.state.zoneId,
        status = self.state.status,
        activeInstanceId = self.state.activeWorldEventInstanceId,
        activeRole = self.state.activeWorldEventRole,
        parentActive = self.state.parentActive == true,
        eventName = self.state.eventName,
        phaseName = self.state.phaseName,
        stepDefId = self.state.currentStepDefId,
        mapLocationIndex = self.state.currentMapLocationIndex,
        participating = self.state.isParticipating == true,
        participatingInstanceId = self.state.participatingInstanceId,
        progressCurrent = self.state.currentProgress,
        progressMax = self.state.maxProgress,
        progressSource = self.state.progressSource,
        stepOrdinal = self.state.currentStepOrdinal,
        stepTotal = self.state.currentStepTotal,
        chestCandidateCount = self.state.chestCandidateCount or 0,
        chestRuleId = self.state.lastChestRuleId,
        participatedSteps = self:GetParticipatedStepListText(),
        chestHint = self.state.chestHintText,
    }

    while #history > self.maxDiagnosticHistory do
        table.remove(history, 1)
    end
end

function DE:ClearDiagnosticHistory()
    self.sv.diagnosticHistory = {}
    self.state.lastDiagnosticSignature = nil
end

function DE:DebugDiagnosticHistory(showAll)
    if not self:IsDebugEnabled() then
        self:Print(self:T("DE_SLASH_DEBUG_DISABLED"))
        return
    end
    local history = self:EnsureDiagnosticHistory()
    local firstIndex = 1
    if not showAll then
        firstIndex = zo_max(1, #history - 49)
    end

    self:DebugPrint(string.format(
        "Diagnostic history: entries=%d showing=%d-%d",
        #history,
        #history > 0 and firstIndex or 0,
        #history
    ))

    for index = firstIndex, #history do
        local entry = history[index]
        self:DebugPrint(string.format(
            "  History[%d]: time=%s source=%s runId=%s zoneId=%s status=%s active=%s/%s parent=%s event=%s phase=%s step=%s map=%s participation=%s participantInstance=%s progress=%s/%s progressSource=%s position=%s/%s participatedSteps=%s chestHints=%s chestRule=%s hint=%s",
            index,
            DebugNumber(entry.timestamp),
            DebugText(entry.source),
            DebugNumber(entry.runId),
            DebugNumber(entry.zoneId),
            DebugText(entry.status),
            DebugNumber(entry.activeInstanceId),
            DebugText(entry.activeRole),
            DebugBool(entry.parentActive),
            DebugText(entry.eventName),
            DebugText(entry.phaseName),
            DebugNumber(entry.stepDefId),
            DebugNumber(entry.mapLocationIndex),
            DebugBool(entry.participating),
            DebugNumber(entry.participatingInstanceId),
            DebugNumber(entry.progressCurrent),
            DebugNumber(entry.progressMax),
            DebugText(entry.progressSource),
            DebugNumber(entry.stepOrdinal),
            DebugNumber(entry.stepTotal),
            DebugText(entry.participatedSteps),
            DebugNumber(entry.chestCandidateCount),
            DebugText(entry.chestRuleId),
            DebugText(entry.chestHint)
        ))
    end
end

local function JoinStepIds(sequence)
    local ids = {}
    for index, entry in ipairs(sequence or {}) do
        ids[index] = tostring(entry.stepDefId)
    end
    return table.concat(ids, ",")
end

local function JoinMapLocationIndices(sequence)
    local indices = {}
    for index, entry in ipairs(sequence or {}) do
        indices[index] = tostring(entry.locationIndex)
    end
    return table.concat(indices, ",")
end

function DE:_DebugEnsureStepLearningZone(zoneId)
    self.sv.stepLearning = self.sv.stepLearning or {}
    local zoneKey = tostring(zoneId or 0)
    local zoneData = self.sv.stepLearning[zoneKey]
    if not zoneData then
        zoneData = {
            steps = {},
            events = {},
            mapLocations = {},
            recentRuns = {},
        }
        self.sv.stepLearning[zoneKey] = zoneData
    end
    zoneData.steps = zoneData.steps or {}
    zoneData.events = zoneData.events or {}
    zoneData.mapLocations = zoneData.mapLocations or {}
    zoneData.recentRuns = zoneData.recentRuns or {}
    return zoneData
end

function DE:_DebugStartStepRun(isExact, source)
    self.state.stepRun = {
        zoneId = self.state.zoneId,
        parentWorldEventInstanceId = self.state.eventData and self.state.eventData.parentWorldEventInstanceId or nil,
        startedAt = GetTimeStamp(),
        startExact = isExact == true,
        startSource = source or "unknown",
        eventName = nil,
        firstStepObservedAt = nil,
        firstMapLocationObservedAt = nil,
        sequence = {},
        seen = {},
        mapLocationSequence = {},
        mapLocationSeen = {},
    }
end

function DE:GetKnownMapLocationCount()
    local zoneData = self.sv.stepLearning and self.sv.stepLearning[tostring(self.state.zoneId)]
    local count = 0
    for _ in pairs(zoneData and zoneData.mapLocations or {}) do
        count = count + 1
    end
    return count
end

function DE:_DebugGetStableLearnedSequence(eventName)
    if not eventName or eventName == "" or not self.sv or not self.sv.stepLearning then
        return nil, nil
    end

    local zoneData = self.sv.stepLearning[tostring(self.state.zoneId)]
    local eventData = zoneData and zoneData.events and zoneData.events[eventName]
    local sequences = eventData and eventData.completedSequences
    if not sequences then
        return nil, nil
    end

    local signature = nil
    local count = nil
    local variants = 0
    for candidateSignature, candidateCount in pairs(sequences) do
        if candidateCount and candidateCount > 0 then
            variants = variants + 1
            signature = candidateSignature
            count = candidateCount
        end
    end

    -- Require 2 matching completed observations before showing x/y.
    if variants ~= 1 or not count or count < 2 then
        return nil, nil
    end

    -- variants == 1 guarantees the loop above assigned signature exactly
    -- once (variants and signature are always set together per iteration),
    -- so signature is a string here even though the LS cannot correlate the
    -- counter with the separate signature variable. Same class of false
    -- positive as docs/KNOWLEDGE.md section 2 ("need-check-nil bei
    -- paarweise korrelierten Feldern"), here via a loop counter instead of
    -- a flag+timestamp pair.
    local sequence = {}
    for idText in string.gmatch(signature, "[^,]+") do ---@diagnostic disable-line: param-type-mismatch
        sequence[#sequence + 1] = tonumber(idText)
    end
    return sequence, count
end

function DE:_DebugGetStableLearnedLocationSequence(eventName)
    if not eventName or eventName == "" or not self.sv or not self.sv.stepLearning then
        return nil, nil
    end

    local zoneData = self.sv.stepLearning[tostring(self.state.zoneId)]
    local eventData = zoneData and zoneData.events and zoneData.events[eventName]
    local sequences = eventData and eventData.completedLocationSequences
    if not sequences then
        return nil, nil
    end

    local signature = nil
    local count = nil
    local variants = 0
    for candidateSignature, candidateCount in pairs(sequences) do
        if candidateCount and candidateCount > 0 then
            variants = variants + 1
            signature = candidateSignature
            count = candidateCount
        end
    end

    if variants ~= 1 or not count or count < 2 then
        return nil, nil
    end

    -- Same false positive as _DebugGetStableLearnedSequence above: variants
    -- == 1 guarantees signature was assigned exactly once in the loop.
    local sequence = {}
    for indexText in string.gmatch(signature, "[^,]+") do ---@diagnostic disable-line: param-type-mismatch
        sequence[#sequence + 1] = tonumber(indexText)
    end
    return sequence, count
end

function DE:StoreStepRunObservation(run, outcome, reason)
    local hasStepSequence = run and run.sequence and #run.sequence > 0
    local hasMapLocationSequence = run and run.mapLocationSequence and #run.mapLocationSequence > 0
    if not hasStepSequence and not hasMapLocationSequence then
        return
    end

    local zoneData = self:EnsureStepLearningZone(run.zoneId)
    local recentRuns = zoneData.recentRuns
    recentRuns[#recentRuns + 1] = {
        observedAt = GetTimeStamp(),
        eventName = run.eventName,
        sequence = JoinStepIds(run.sequence),
        mapLocationSequence = JoinMapLocationIndices(run.mapLocationSequence),
        startAt = run.startedAt,
        startExact = run.startExact == true,
        startSource = run.startSource,
        firstStepObservedAt = run.firstStepObservedAt,
        firstMapLocationObservedAt = run.firstMapLocationObservedAt,
        endAt = run.endedAt,
        endExact = run.endExact == true,
        endSource = run.endSource,
        outcome = outcome or "unknown",
        reason = reason,
    }

    while #recentRuns > 20 do
        table.remove(recentRuns, 1)
    end
end

function DE:_DebugFinalizeStepRun(endExact, source)
    local run = self.state.stepRun
    if not run then
        return
    end

    run.endedAt = GetTimeStamp()
    run.endExact = endExact == true
    run.endSource = source or "unknown"

    local eventName = run.eventName or self.state.eventName
    local sequence = run.sequence or {}
    self:StoreStepRunObservation(run, "ended", source)
    local firstStepWasNearStart = run.startExact
        and run.firstStepObservedAt
        and (run.firstStepObservedAt - run.startedAt) <= 15

    -- Only exact, uninterrupted full runs count toward learning x/y.
    if eventName and #sequence > 0 and firstStepWasNearStart and run.endExact then
        local zoneData = self:EnsureStepLearningZone(run.zoneId)
        local learnedEvent = zoneData.events[eventName] or {
            completedSequences = {},
            completedLocationSequences = {},
            completedRuns = 0,
        }
        learnedEvent.completedSequences = learnedEvent.completedSequences or {}
        learnedEvent.completedLocationSequences = learnedEvent.completedLocationSequences or {}
        local signature = JoinStepIds(sequence)
        learnedEvent.completedSequences[signature] = (learnedEvent.completedSequences[signature] or 0) + 1
        learnedEvent.completedRuns = (learnedEvent.completedRuns or 0) + 1
        learnedEvent.lastCompletedAt = run.endedAt
        learnedEvent.lastSequence = signature
        zoneData.events[eventName] = learnedEvent
    end

    local mapLocationSequence = run.mapLocationSequence or {}
    local firstMapLocationWasNearStart = run.startExact
        and run.firstMapLocationObservedAt
        and (run.firstMapLocationObservedAt - run.startedAt) <= 15
    if eventName and #mapLocationSequence > 0 and firstMapLocationWasNearStart and run.endExact then
        local zoneData = self:EnsureStepLearningZone(run.zoneId)
        local learnedEvent = zoneData.events[eventName] or {
            completedSequences = {},
            completedLocationSequences = {},
            completedRuns = 0,
        }
        learnedEvent.completedLocationSequences = learnedEvent.completedLocationSequences or {}
        local signature = JoinMapLocationIndices(mapLocationSequence)
        learnedEvent.completedLocationSequences[signature] = (learnedEvent.completedLocationSequences[signature] or 0) + 1
        learnedEvent.completedLocationRuns = (learnedEvent.completedLocationRuns or 0) + 1
        learnedEvent.lastLocationSequence = signature
        learnedEvent.lastCompletedAt = run.endedAt
        zoneData.events[eventName] = learnedEvent
    end
end

function DE:_DebugResetStepRun(reason)
    local run = self.state.stepRun
    if run then
        run.resetAt = GetTimeStamp()
        run.resetReason = reason or "unspecified"
        self:StoreStepRunObservation(run, "interrupted", run.resetReason)
    end
    self.state.stepRun = nil
    self:ClearCurrentStepState()
end

function DE:DebugStepLearning()
    local run = self.state.stepRun
    self:DebugPrint(string.format(
        "Step state: eventName=%s stepDefId=%s source=%s phase=%s learnedOrdinal=%s learnedTotal=%s mapLocationIndex=%s mapSource=%s mapCandidates=%s mapReason=%s",
        DebugText(self.state.eventName),
        DebugNumber(self.state.currentStepDefId),
        DebugText(self.state.currentStepSource),
        DebugText(self.state.phaseName),
        DebugNumber(self.state.currentStepOrdinal),
        DebugNumber(self.state.currentStepTotal),
        DebugNumber(self.state.currentMapLocationIndex),
        DebugText(self.state.currentMapLocationSource),
        DebugNumber(self.state.currentMapLocationCandidateCount),
        DebugText(self.state.currentMapLocationScanReason)
    ))

    if run then
        self:DebugPrint(string.format(
            "Current step run: startAt=%s exact=%s source=%s eventName=%s firstStepAt=%s stepSequence=%s firstMapLocationAt=%s mapLocationSequence=%s",
            DebugNumber(run.startedAt),
            DebugBool(run.startExact),
            DebugText(run.startSource),
            DebugText(run.eventName),
            DebugNumber(run.firstStepObservedAt),
            JoinStepIds(run.sequence),
            DebugNumber(run.firstMapLocationObservedAt),
            JoinMapLocationIndices(run.mapLocationSequence)
        ))
        for index, entry in ipairs(run.sequence) do
            self:DebugPrint(string.format(
                "  RunStep[%d]: stepDefId=%s name=%s description=%s observedAt=%s source=%s",
                index,
                DebugNumber(entry.stepDefId),
                DebugText(entry.name),
                DebugText(entry.description),
                DebugNumber(entry.observedAt),
                DebugText(entry.source)
            ))
        end
        for index, entry in ipairs(run.mapLocationSequence or {}) do
            self:DebugPrint(string.format(
                "  RunMapLocation[%d]: locationIndex=%s header=%s description=%s observedAt=%s source=%s",
                index,
                DebugNumber(entry.locationIndex),
                DebugText(entry.header),
                DebugText(entry.description),
                DebugNumber(entry.observedAt),
                DebugText(entry.source)
            ))
        end
    else
        self:DebugPrint("Current step run: none")
    end

    local zoneData = self.sv.stepLearning and self.sv.stepLearning[tostring(self.state.zoneId)]
    if not zoneData then
        self:DebugPrint("Learned step data for current zone: none")
        return
    end

    local stepCount = 0
    for _ in pairs(zoneData.steps or {}) do
        stepCount = stepCount + 1
    end
    local eventCount = 0
    for _ in pairs(zoneData.events or {}) do
        eventCount = eventCount + 1
    end
    local mapLocationCount = 0
    for _ in pairs(zoneData.mapLocations or {}) do
        mapLocationCount = mapLocationCount + 1
    end
    self:DebugPrint(string.format("Learned step data: uniqueStepIds=%d uniqueMapLocations=%d eventGroups=%d recentRuns=%d", stepCount, mapLocationCount, eventCount, #(zoneData.recentRuns or {})))

    local firstRunIndex = zo_max(1, #(zoneData.recentRuns or {}) - 9)
    for index = firstRunIndex, #(zoneData.recentRuns or {}) do
        local learnedRun = zoneData.recentRuns[index]
        self:DebugPrint(string.format(
            "  ObservedRun[%d]: outcome=%s reason=%s eventName=%s stepSequence=%s mapLocationSequence=%s startAt=%s startExact=%s firstStepAt=%s firstMapLocationAt=%s endAt=%s endExact=%s",
            index,
            DebugText(learnedRun.outcome),
            DebugText(learnedRun.reason),
            DebugText(learnedRun.eventName),
            DebugText(learnedRun.sequence),
            DebugText(learnedRun.mapLocationSequence),
            DebugNumber(learnedRun.startAt),
            DebugBool(learnedRun.startExact),
            DebugNumber(learnedRun.firstStepObservedAt),
            DebugNumber(learnedRun.firstMapLocationObservedAt),
            DebugNumber(learnedRun.endAt),
            DebugBool(learnedRun.endExact)
        ))
    end

    local eventNames = {}
    for eventName in pairs(zoneData.events or {}) do
        eventNames[#eventNames + 1] = eventName
    end
    table.sort(eventNames)
    for _, eventName in ipairs(eventNames) do
        local learnedEvent = zoneData.events[eventName]
        local stableSequence, stableCount = self:GetStableLearnedSequence(eventName)
        local stableLocationSequence, stableLocationCount = self:GetStableLearnedLocationSequence(eventName)
        self:DebugPrint(string.format(
            "  LearnedEvent: name=%s completedStepRuns=%s completedMapLocationRuns=%s stableStepSequence=%s stableStepCount=%s lastStepSequence=%s stableMapLocationSequence=%s stableMapLocationCount=%s lastMapLocationSequence=%s",
            DebugText(eventName),
            DebugNumber(learnedEvent.completedRuns),
            DebugNumber(learnedEvent.completedLocationRuns),
            stableSequence and table.concat(stableSequence, ",") or "-",
            DebugNumber(stableCount),
            DebugText(learnedEvent.lastSequence),
            stableLocationSequence and table.concat(stableLocationSequence, ",") or "-",
            DebugNumber(stableLocationCount),
            DebugText(learnedEvent.lastLocationSequence)
        ))
        local signatures = {}
        for signature in pairs(learnedEvent.completedSequences or {}) do
            signatures[#signatures + 1] = signature
        end
        table.sort(signatures)
        for _, signature in ipairs(signatures) do
            self:DebugPrint(string.format(
                "    Sequence: ids=%s count=%s",
                signature,
                DebugNumber(learnedEvent.completedSequences[signature])
            ))
        end
        local locationSignatures = {}
        for signature in pairs(learnedEvent.completedLocationSequences or {}) do
            locationSignatures[#locationSignatures + 1] = signature
        end
        table.sort(locationSignatures)
        for _, signature in ipairs(locationSignatures) do
            self:DebugPrint(string.format(
                "    MapLocationSequence: indices=%s count=%s",
                signature,
                DebugNumber(learnedEvent.completedLocationSequences[signature])
            ))
        end
    end
end

function DE:DebugCycleMeasurements()
    local measurement = self:EnsureMeasurementState()

    self:DebugPrint(string.format(
        "Respawn measurement: enabled=%s chainId=%d resetAt=%s resetReason=%s",
        DebugBool(self:IsRespawnMeasurementEnabled()),
        measurement.chainId or 0,
        DebugNumber(measurement.chainResetAt),
        DebugText(measurement.chainResetReason)
    ))

    local configs = self:GetRespawnMeasurementConfigsForCurrentZone() or {}
    for _, config in ipairs(configs) do
        local key = self:GetEncounterMeasurementKey(config)
        local runtime = self:GetMeasurementRuntime(config, false)
        local data = self:EnsureSavedRespawnMeasurement(config)
        local samples = data and data.samples or {}

        self:DebugPrint(string.format(
            "  RespawnEncounter: key=%s zoneId=%s samples=%d/%d",
            DebugText(key),
            DebugNumber(config.zoneId),
            #samples,
            self.maxRespawnMeasurements
        ))

        if runtime then
            self:DebugPrint(string.format(
                "    Runtime: lastStartAt=%s lastStartExact=%s lastEndAt=%s lastEndExact=%s currentStartObservedAt=%s currentStartExact=%s currentStartSource=%s lastEndObservedAt=%s lastEndSource=%s lastEventDuration=%s(%s)",
                DebugNumber(runtime.lastStartAt),
                DebugBool(runtime.lastStartExact),
                DebugNumber(runtime.lastEndAt),
                DebugBool(runtime.lastEndExact),
                DebugNumber(runtime.currentStartObservedAt),
                DebugBool(runtime.currentStartExact),
                DebugText(runtime.currentStartSource),
                DebugNumber(runtime.lastDeactivationObservedAt),
                DebugText(runtime.lastDeactivationSource),
                DebugNumber(runtime.lastEventDuration),
                FormatDebugDuration(runtime.lastEventDuration)
            ))
        else
            self:DebugPrint("    Runtime: no observation in current measurement chain")
        end

        local endStats = CalculateMeasurementStats(CollectMeasurementValues(samples, "endToStart"))
        local startStats = CalculateMeasurementStats(CollectMeasurementValues(samples, "startToStart"))
        local durationStats = CalculateMeasurementStats(CollectMeasurementValues(samples, "previousEventDuration"))
        self:DebugPrint("    EndToStart: " .. FormatMeasurementStats(endStats))
        self:DebugPrint("    StartToStart: " .. FormatMeasurementStats(startStats))
        self:DebugPrint("    EventDuration: " .. FormatMeasurementStats(durationStats))

        local firstIndex = zo_max(1, #samples - 9)
        for index = firstIndex, #samples do
            local sample = samples[index]
            self:DebugPrint(string.format(
                "    Sample[%d]: chainId=%s previousStart=%s previousEnd=%s currentStart=%s eventDuration=%s(%s) startToStart=%s(%s) endToStart=%s(%s) source=%s",
                index,
                DebugNumber(sample.chainId),
                DebugNumber(sample.previousStartAt),
                DebugNumber(sample.previousEndAt),
                DebugNumber(sample.currentStartAt),
                DebugNumber(sample.previousEventDuration),
                FormatDebugDuration(sample.previousEventDuration),
                DebugNumber(sample.startToStart),
                FormatDebugDuration(sample.startToStart),
                DebugNumber(sample.endToStart),
                FormatDebugDuration(sample.endToStart),
                DebugText(sample.startSource)
            ))
        end
    end
end

function DE:DebugPrint(message)
    self:Print(string.format("|cA8A8A8API DEBUG|r %s", tostring(message)))
end

function DE:DebugParticipatingWorldEvent()
    local participatingInstanceId, stepDefId = GetParticipatingWorldEventStep()

    self:DebugPrint(string.format(
        "Participation: instanceId=%s stepDefId=%s",
        DebugNumber(participatingInstanceId),
        DebugNumber(stepDefId)
    ))

    if participatingInstanceId == 0 or stepDefId == 0 then
        self:DebugPrint("Participation details: no current participating World Event step.")
        return
    end

    local stepName = GetWorldEventStepName(participatingInstanceId, stepDefId)
    local stepDescription = GetWorldEventStepDescription(stepDefId)
    local timerTextOverride = GetWorldEventStepTimerTextOverride()
    local currentProgress, maxProgress = GetWorldEventCurrentStepProgress(participatingInstanceId)
    local expireTimeS = GetWorldEventCurrentStepExpireTimeS(participatingInstanceId)
    local remainingS = expireTimeS ~= 0 and zo_max(expireTimeS - GetTimeStamp(), 0) or 0

    self:DebugPrint(string.format(
        "Participation step: name=%s description=%s timerOverride=%s",
        DebugText(stepName),
        DebugText(stepDescription),
        DebugText(timerTextOverride)
    ))
    self:DebugPrint(string.format(
        "Participation progress: current=%s max=%s expireTimeS=%s remainingS=%s",
        DebugNumber(currentProgress),
        DebugNumber(maxProgress),
        DebugNumber(expireTimeS),
        DebugNumber(remainingS)
    ))
end

function DE:DebugWorldEventPOI(worldEventInstanceId, zoneIndex, poiIndex, source)
    local zoneId = GetZoneId(zoneIndex)
    local zoneName = zo_strformat(SI_ZONE_NAME, GetZoneNameById(zoneId))
    local poiName = GetPOIInfo(zoneIndex, poiIndex)
    local poiType = GetPOIType(zoneIndex, poiIndex)
    local poiInstanceType = GetPOIInstanceType(zoneIndex, poiIndex)
    local poiWorldEventInstanceId = GetPOIWorldEventInstanceId(zoneIndex, poiIndex)

    local x, y, pinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby = GetPOIMapInfo(zoneIndex, poiIndex)

    self:DebugPrint(string.format(
        "  POI: source=%s zoneIndex=%d zoneId=%d zone=%s poiIndex=%d name=%s",
        DebugText(source),
        zoneIndex,
        zoneId,
        DebugText(zoneName),
        poiIndex,
        DebugText(poiName)
    ))
    self:DebugPrint(string.format(
        "  POI data: poiType=%s instanceType=%s linkedWorldEventInstanceId=%s matchesIterator=%s",
        DebugNumber(poiType),
        DebugNumber(poiInstanceType),
        DebugNumber(poiWorldEventInstanceId),
        DebugBool(poiWorldEventInstanceId == worldEventInstanceId)
    ))
    self:DebugPrint(string.format(
        "  POI map: x=%s y=%s pinType=%s shown=%s discovered=%s nearby=%s lockedCollectible=%s",
        DebugNumber(x, 5),
        DebugNumber(y, 5),
        DebugNumber(pinType),
        DebugBool(isShownInCurrentMap),
        DebugBool(isDiscovered),
        DebugBool(isNearby),
        DebugBool(linkedCollectibleIsLocked)
    ))
    self:DebugPrint(string.format("  POI icon: %s", DebugText(icon)))
end

function DE:DebugWorldEventUnits(worldEventInstanceId)
    local numUnits = GetNumWorldEventInstanceUnits(worldEventInstanceId)
    self:DebugPrint(string.format("  Units: count=%d", numUnits))

    for unitIndex = 1, numUnits do
        local unitTag = GetWorldEventInstanceUnitTag(worldEventInstanceId, unitIndex)
        local pinType = GetWorldEventInstanceUnitPinType(worldEventInstanceId, unitTag)
        local x, y, heading, isInCurrentMap, isSymbolicLocation = GetMapPlayerPosition(unitTag)
        local unitExists = DoesUnitExist(unitTag)
        local unitName = unitExists and GetUnitName(unitTag) or ""

        self:DebugPrint(string.format(
            "    Unit[%d]: tag=%s exists=%s name=%s pinType=%s",
            unitIndex,
            DebugText(unitTag),
            DebugBool(unitExists),
            DebugText(unitName),
            DebugNumber(pinType)
        ))
        self:DebugPrint(string.format(
            "    Unit[%d] map: x=%s y=%s heading=%s currentMap=%s symbolic=%s",
            unitIndex,
            DebugNumber(x, 5),
            DebugNumber(y, 5),
            DebugNumber(heading, 5),
            DebugBool(isInCurrentMap),
            DebugBool(isSymbolicLocation)
        ))
    end
end

function DE:DebugWorldEventInstance(worldEventInstanceId, ordinal)
    local worldEventId = GetWorldEventId(worldEventInstanceId)
    local worldEventType = type(worldEventId) == "number" and worldEventId ~= 0 and GetWorldEventType(worldEventId) or 0
    local worldEventTypeName = WORLD_EVENT_TYPE_NAMES[worldEventType] or "UNKNOWN"
    local locationContext = GetWorldEventLocationContext(worldEventInstanceId)
    local locationContextName = WORLD_EVENT_LOCATION_CONTEXT_NAMES[locationContext] or "UNKNOWN"
    local role = self:GetTrackedWorldEventRole(worldEventInstanceId) or "not-tracked"

    local progressSucceeded, currentProgress, maxProgress = pcall(GetWorldEventCurrentStepProgress, worldEventInstanceId)
    local expireSucceeded, expireTimeS = pcall(GetWorldEventCurrentStepExpireTimeS, worldEventInstanceId)
    if not progressSucceeded then
        currentProgress = nil
        maxProgress = nil
    end
    if not expireSucceeded then
        expireTimeS = nil
    end
    local remainingS = type(expireTimeS) == "number" and expireTimeS ~= 0 and zo_max(expireTimeS - GetTimeStamp(), 0) or 0

    self:DebugPrint(string.format("--- World Event #%d ---", ordinal))
    self:DebugPrint(string.format(
        "  Core: instanceId=%d eventId=%s type=%s(%s) context=%s(%s) role=%s",
        worldEventInstanceId,
        DebugNumber(worldEventId),
        worldEventTypeName,
        DebugNumber(worldEventType),
        locationContextName,
        DebugNumber(locationContext),
        role
    ))
    self:DebugPrint(string.format(
        "  Current step data: progress=%s max=%s expireTimeS=%s remainingS=%s progressCall=%s expireCall=%s",
        DebugNumber(currentProgress),
        DebugNumber(maxProgress),
        DebugNumber(expireTimeS),
        DebugNumber(remainingS),
        DebugBool(progressSucceeded),
        DebugBool(expireSucceeded)
    ))

    local linkedZoneIndex, linkedPOIIndex, linkedPOISource = self:GetWorldEventPOIIndices(worldEventInstanceId)
    if linkedZoneIndex and linkedPOIIndex then
        self:DebugWorldEventPOI(worldEventInstanceId, linkedZoneIndex, linkedPOIIndex, linkedPOISource)
    elseif locationContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST then
        local zoneIndex, poiIndex = GetWorldEventPOIInfo(worldEventInstanceId)
        self:DebugPrint(string.format(
            "  POI: direct API returned zoneIndex=%s poiIndex=%s but no matching GetPOIWorldEventInstanceId link was found.",
            DebugNumber(zoneIndex),
            DebugNumber(poiIndex)
        ))
    elseif locationContext == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
        self:DebugWorldEventUnits(worldEventInstanceId)
    else
        self:DebugPrint("  Location: no UNIT/POI context and no linked POI found in the current zone.")
    end
end

function DE:DebugCurrentZoneWorldEventPOILinks(zoneIndex)
    local numPOIs = GetNumPOIs(zoneIndex)
    local linkedCount = 0

    self:DebugPrint(string.format(
        "Current-zone POI scan: zoneIndex=%d numPOIs=%d",
        zoneIndex,
        numPOIs
    ))

    for poiIndex = 1, numPOIs do
        local linkedWorldEventInstanceId = GetPOIWorldEventInstanceId(zoneIndex, poiIndex)
        if linkedWorldEventInstanceId and linkedWorldEventInstanceId ~= 0 then
            linkedCount = linkedCount + 1
            local poiName = GetPOIInfo(zoneIndex, poiIndex)
            local formattedPOIName = poiName and poiName ~= "" and zo_strformat(SI_ZONE_NAME, poiName) or nil
            self:DebugPrint(string.format(
                "  Linked POI #%d: poiIndex=%d linkedWorldEventInstanceId=%d rawName=%s localizedName=%s",
                linkedCount,
                poiIndex,
                linkedWorldEventInstanceId,
                DebugText(poiName),
                DebugText(formattedPOIName)
            ))
        end
    end

    self:DebugPrint(string.format("Current-zone POI links found=%d", linkedCount))
end

function DE:DebugDynamicEncounterTrackerMapLocations()
    local playerZoneIndex = GetUnitZoneIndex("player")
    local mapZoneIndex = GetCurrentMapZoneIndex()
    local numLocations = GetNumMapLocations()
    local locationData, candidates, reason = self:GetVisibleDynamicEncounterTrackerMapLocation()

    self:DebugPrint(string.format(
        "Dynamic map-location scan: playerZoneIndex=%s currentMapZoneIndex=%s numMapLocations=%s visibleDynamicCandidates=%s selectedLocationIndex=%s reason=%s iconFilter=%s",
        DebugNumber(playerZoneIndex),
        DebugNumber(mapZoneIndex),
        DebugNumber(numLocations),
        DebugNumber(#candidates),
        locationData and DebugNumber(locationData.locationIndex) or "-",
        DebugText(reason),
        DebugText(self.dynamicEventMapLocationIcon)
    ))

    for candidateIndex, candidate in ipairs(candidates) do
        self:DebugPrint(string.format(
            "  DynamicLocation[%d]: locationIndex=%s header=%s description=%s icon=%s x=%s y=%s lineCount=%s",
            candidateIndex,
            DebugNumber(candidate.locationIndex),
            DebugText(candidate.header),
            DebugText(candidate.description),
            DebugText(candidate.icon),
            DebugNumber(candidate.x, 5),
            DebugNumber(candidate.y, 5),
            DebugNumber(#(candidate.lines or {}))
        ))
        for _, line in ipairs(candidate.lines or {}) do
            self:DebugPrint(string.format(
                "    Line[%s]: grouping=%s category=%s name=%s icon=%s",
                DebugNumber(line.lineIndex),
                DebugNumber(line.groupingId),
                DebugText(line.categoryName),
                DebugText(line.name),
                DebugText(line.icon)
            ))
        end
    end
end

function DE:DebugWorldEvents()
    if not self:IsDebugEnabled() then
        self:Print(self:T("DE_SLASH_DEBUG_DISABLED"))
        return
    end
    if not self:IsZoneRuntimeEnabled() then
        self:Print(self:T("DE_SLASH_DEBUG_ZONE_REQUIRED"))
        return
    end

    self:UpdateCurrentZone(false)
    local scanDetected = self:ScanActiveWorldEvents()

    local zoneIndex = GetUnitZoneIndex("player")
    local zoneId = GetZoneId(zoneIndex)
    local zoneName = zo_strformat(SI_ZONE_NAME, GetZoneNameById(zoneId))
    local supported = self:GetZoneEncounterConfigs(zoneId) ~= nil

    self:DebugPrint("========== START ==========")
    self:DebugPrint(string.format(
        "Addon=%s version=%s apiVersion=%s world=%s timestamp=%s",
        self.displayName,
        self.version,
        DebugNumber(GetAPIVersion()),
        DebugText(GetWorldName()),
        DebugNumber(GetTimeStamp())
    ))
    self:DebugPrint(string.format(
        "Player zone: zoneIndex=%d zoneId=%d name=%s supported=%s",
        zoneIndex,
        zoneId,
        DebugText(zoneName),
        DebugBool(supported)
    ))
    self:DebugPrint(string.format(
        "Addon state: status=%s activeInstanceId=%s activeRole=%s parentActive=%s eventName=%s phase=%s stepDefId=%s stepPosition=%s/%s mapLocationIndex=%s mapSource=%s participation=%s participantInstance=%s progress=%s/%s progressSource=%s chestHints=%s hintUntil=%s noActiveSince=%s scanDetected=%s",
        DebugText(self.state.status),
        DebugNumber(self.state.activeWorldEventInstanceId),
        DebugText(self.state.activeWorldEventRole),
        DebugBool(self.state.parentActive),
        DebugText(self.state.eventName),
        DebugText(self.state.phaseName),
        DebugNumber(self.state.currentStepDefId),
        DebugNumber(self.state.currentStepOrdinal),
        DebugNumber(self.state.currentStepTotal),
        DebugNumber(self.state.currentMapLocationIndex),
        DebugText(self.state.currentMapLocationSource),
        DebugBool(self.state.isParticipating),
        DebugNumber(self.state.participatingInstanceId),
        DebugNumber(self.state.currentProgress),
        DebugNumber(self.state.maxProgress),
        DebugText(self.state.progressSource),
        DebugNumber(self.state.chestCandidateCount),
        DebugNumber(self.state.chestHintUntil),
        DebugNumber(self.state.noActiveSince),
        DebugBool(scanDetected)
    ))
    self:DebugPrint(string.format(
        "Periodic scan: intervalMs=%d runtimeEnabled=%s zoneRuntimeActive=%s debugEnabled=%s",
        self.scanIntervalMs,
        DebugBool(self.state.runtimeEnabled),
        DebugBool(self.state.zoneRuntimeActive),
        DebugBool(self:IsDebugEnabled())
    ))
    local respawnTiming = self.state.eventData and self:GetRespawnTiming(self.state.eventData) or nil
    self:DebugPrint(string.format(
        "Cooldown estimate: startedAt=%s exact=%s source=%s earliestAt=%s expectedAt=%s earliestSeconds=%s expectedSeconds=%s",
        DebugNumber(self.state.cooldownStartedAt),
        DebugBool(self.state.cooldownStartExact),
        DebugText(self.state.cooldownSource),
        DebugNumber(self.state.earliestRespawnAt),
        DebugNumber(self.state.respawnAt),
        respawnTiming and DebugNumber(respawnTiming.earliestSeconds) or "-",
        respawnTiming and DebugNumber(respawnTiming.expectedSeconds) or "-"
    ))

    if self.state.eventData then
        local childIds = {}
        for childInstanceId in pairs(self.state.eventData.knownChildInstanceIds) do
            childIds[#childIds + 1] = childInstanceId
        end
        table.sort(childIds)

        -- respawnTiming was assigned above from `self.state.eventData and
        -- self:GetRespawnTiming(...)`, so it is non-nil whenever
        -- self.state.eventData is truthy, exactly the condition guarding
        -- this block. The LS cannot correlate the two separate `if`
        -- checks on the same expression.
        self:DebugPrint(string.format(
            "Configured event: parentInstanceId=%d childInstanceIds=%s earliestSeconds=%d expectedSeconds=%d",
            self.state.eventData.parentWorldEventInstanceId,
            table.concat(childIds, ","),
            respawnTiming.earliestSeconds, ---@diagnostic disable-line: need-check-nil, undefined-field
            respawnTiming.expectedSeconds ---@diagnostic disable-line: need-check-nil, undefined-field
        ))
    end

    self:DebugCycleMeasurements()
    self:DebugStepLearning()
    self:DebugDiagnosticHistory(false)
    self:DebugParticipatingWorldEvent()
    self:DebugDynamicEncounterTrackerMapLocations()
    self:DebugCurrentZoneWorldEventPOILinks(zoneIndex)

    local count = 0
    for worldEventInstanceId in WorldEventInstanceIterator do
        count = count + 1
        local succeeded, errorMessage = pcall(function()
            self:DebugWorldEventInstance(worldEventInstanceId, count)
        end)

        if not succeeded then
            self:DebugPrint(string.format(
                "--- World Event #%d instanceId=%s ERROR: %s",
                count,
                DebugNumber(worldEventInstanceId),
                DebugText(errorMessage)
            ))
        end
    end

    self:DebugPrint(string.format("Iterator result: activeWorldEventCount=%d", count))
    if count == 0 then
        self:DebugPrint("Die API meldet derzeit keine aktive World-Event-Instanz.")
    end
    self:DebugPrint("=========== END ===========")
end

function Debug:Initialize()
    DE.sv.stepLearning = DE.sv.stepLearning or {}
    DE.sv.diagnosticHistory = DE.sv.diagnosticHistory or {}
end

function Debug:RecordDiagnosticSnapshot(source, force)
    return DE:_DebugRecordDiagnosticSnapshot(source, force)
end

function Debug:EnsureStepLearningZone(zoneId)
    return DE:_DebugEnsureStepLearningZone(zoneId)
end

function Debug:StartStepRun(isExact, source)
    return DE:_DebugStartStepRun(isExact, source)
end

function Debug:FinalizeStepRun(endExact, source)
    return DE:_DebugFinalizeStepRun(endExact, source)
end

function Debug:ResetStepRun(reason)
    return DE:_DebugResetStepRun(reason)
end

function Debug:GetStableLearnedSequence(eventName)
    return DE:_DebugGetStableLearnedSequence(eventName)
end

function Debug:GetStableLearnedLocationSequence(eventName)
    return DE:_DebugGetStableLearnedLocationSequence(eventName)
end

function DE:GetDetectionText()
    if self.state.status == self.STATUS_COOLDOWN then
        return self.state.cooldownStartExact and "Parent beendet · Cooldown exakt erkannt" or "Parent nicht aktiv · Cooldown geschätzt"
    end
    if self.state.status ~= self.STATUS_ACTIVE then
        return "-"
    end

    local parts = {}
    if self.state.activeWorldEventInstanceId then
        parts[#parts + 1] = string.format("Child %d", self.state.activeWorldEventInstanceId)
    end
    parts[#parts + 1] = self.state.parentActive and "Parent aktiv" or "Parent nicht gesehen"
    if self.state.currentStepDefId then
        parts[#parts + 1] = string.format("Step %d", self.state.currentStepDefId)
    end
    if self.state.currentMapLocationIndex then
        parts[#parts + 1] = string.format("Map %d", self.state.currentMapLocationIndex)
    end
    return #parts > 0 and table.concat(parts, " · ") or "-"
end

function DE:GetParticipationDebugText()
    local remembered = self:GetParticipatedStepListText()
    if self.state.status == self.STATUS_ACTIVE then
        local current = self.state.isParticipating and "Aktuell bestätigt" or "Aktuell nicht bestätigt"
        if remembered ~= "-" then
            return string.format("%s · gemerkte Steps: %s", current, remembered)
        end
        return current
    end

    if remembered ~= "-" then
        return string.format("Gemerkte Steps: %s", remembered)
    end
    return "-"
end

function DE:GetApiDebugText()
    local parts = {}
    if self.state.currentStepSource then
        parts[#parts + 1] = "Step: " .. tostring(self.state.currentStepSource)
    end
    if self.state.progressSource then
        parts[#parts + 1] = "Progress: " .. tostring(self.state.progressSource)
    end
    if self.state.currentMapLocationSource then
        parts[#parts + 1] = "Map: " .. tostring(self.state.currentMapLocationSource)
    end
    if self.state.cooldownSource then
        parts[#parts + 1] = "Cooldown: " .. tostring(self.state.cooldownSource)
    end
    return #parts > 0 and table.concat(parts, " · ") or "-"
end

function DE:GetTestDebugText()
    local configuredCount = self.GetConfiguredChestRuleCount and self:GetConfiguredChestRuleCount() or 0
    if configuredCount <= 0 then
        return "Kistenmodus: nicht konfiguriert · keine Anzeige"
    end

    local parts = {
        "Kistenmodus: feste Zonenlogik",
        string.format("Kisten: %d/%d", self.state.chestCandidateCount or 0, configuredCount),
    }
    if self.state.lastChestRuleId then
        parts[#parts + 1] = "Regel: " .. tostring(self.state.lastChestRuleId)
    end
    return table.concat(parts, " · ")
end

local function SetLabelColor(label, color)
    label:SetColor(color[1], color[2], color[3], color[4] or 1)
end

local function FormatProgress(currentProgress, maxProgress)
    if type(currentProgress) ~= "number" or type(maxProgress) ~= "number" or maxProgress <= 0 then
        return DE:T("DE_PROGRESS_UNKNOWN")
    end
    local percent = zo_floor((currentProgress / maxProgress) * 100 + 0.5)
    return string.format("%s/%s (%d%%)", tostring(currentProgress), tostring(maxProgress), percent)
end

function Debug:CreateStatusRows(window)
    DE.debugRows = {
        progress = DE:CreateRow(window, "DynamicEncounterTrackerProgress", 207, false),
        participation = DE:CreateRow(window, "DynamicEncounterTrackerParticipation", 234, true),
        detection = DE:CreateRow(window, "DynamicEncounterTrackerDetection", 261, true),
        api = DE:CreateRow(window, "DynamicEncounterTrackerApi", 288, true),
        test = DE:CreateRow(window, "DynamicEncounterTrackerTest", 315, true),
    }
    DE.debugRows.progress.label:SetText(DE:T("DE_LABEL_PROGRESS"))
    DE.debugRows.participation.label:SetText(DE:T("DE_LABEL_PARTICIPATION"))
    DE.debugRows.detection.label:SetText(DE:T("DE_LABEL_DETECTION"))
    DE.debugRows.api.label:SetText(DE:T("DE_LABEL_API"))
    DE.debugRows.test.label:SetText(DE:T("DE_LABEL_TEST"))

    DE.debugDivider = WM:CreateControl("DynamicEncounterTrackerWindowDebugDivider", window, CT_TEXTURE)
    DE.debugDivider:SetHeight(1)
    DE.debugDivider:SetTexture("EsoUI/Art/Miscellaneous/horizontalDivider.dds")

    DE.debugTitleLabel = WM:CreateControl("DynamicEncounterTrackerWindowDebugTitle", window, CT_LABEL)
    DE.debugTitleLabel:SetHeight(20)
    DE.debugTitleLabel:SetText(DE:T("DE_DEBUG_TITLE"))
    DE.debugTitleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    DE.debugTitleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    DE.debugTitleLabel:SetMaxLineCount(1)
end

function Debug:LayoutStatusRows(window, y)
    if not DE.debugRows then
        return y
    end
    local show = DE.sv.debugEnabled == true and DE.sv.showDebugArea ~= false
    DE.debugDivider:SetHidden(not show)
    DE.debugTitleLabel:SetHidden(not show)
    for _, row in pairs(DE.debugRows) do
        row.label:SetHidden(not show)
        row.value:SetHidden(not show)
    end
    if not show then
        return y
    end

    local dividerY = y + 4
    DE.debugDivider:ClearAnchors()
    DE.debugDivider:SetAnchor(TOPLEFT, window, TOPLEFT, 14, dividerY)
    DE.debugDivider:SetAnchor(TOPRIGHT, window, TOPRIGHT, -14, dividerY)

    DE.debugTitleLabel:ClearAnchors()
    DE.debugTitleLabel:SetAnchor(TOPLEFT, window, TOPLEFT, 18, dividerY + 1)
    DE.debugTitleLabel:SetAnchor(TOPRIGHT, window, TOPRIGHT, -30, dividerY + 1)

    y = dividerY + 23
    for _, key in ipairs({ "progress", "participation", "detection", "api", "test" }) do
        local row = DE.debugRows[key]
        local rowHeight = DE:MeasureRowHeight(row)
        DE:PositionRow(row, y, rowHeight)
        y = y + rowHeight + 1
    end
    return y
end

function Debug:ApplyStatusAppearance(normalFont, boldFont, divider)
    if not DE.debugRows then
        return
    end
    DE.debugTitleLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", zo_max(12, DE.sv.textSize - 2)))
    SetLabelColor(DE.debugTitleLabel, DE.sv.colors.label)
    DE.debugDivider:SetColor(divider[1], divider[2], divider[3], (divider[4] or 1) * 0.65)
    for _, row in pairs(DE.debugRows) do
        row.label:SetFont(normalFont)
        row.value:SetFont(boldFont)
        SetLabelColor(row.label, DE.sv.colors.label)
    end
end

function Debug:RefreshStatusRows(active)
    if not DE.debugRows then
        return
    end
    local show = DE.sv.debugEnabled == true and DE.sv.showDebugArea ~= false
    if show then
        DE.debugRows.progress.value:SetText(active and FormatProgress(DE.state.currentProgress, DE.state.maxProgress) or "-")
        DE.debugRows.participation.value:SetText(DE:GetParticipationDebugText())
        DE.debugRows.detection.value:SetText(DE:GetDetectionText())
        DE.debugRows.api.value:SetText(DE:GetApiDebugText())
        DE.debugRows.test.value:SetText(DE:GetTestDebugText())
    else
        for _, row in pairs(DE.debugRows) do
            row.value:SetText("-")
        end
    end
    SetLabelColor(DE.debugRows.progress.value, active and DE.sv.colors.active or DE.sv.colors.unknown)
    SetLabelColor(DE.debugRows.participation.value, active and DE.state.isParticipating and DE.sv.colors.active or DE.sv.colors.unknown)
    SetLabelColor(DE.debugRows.detection.value, DE.sv.colors.value)
    SetLabelColor(DE.debugRows.api.value, DE.sv.colors.value)
    SetLabelColor(DE.debugRows.test.value, DE.sv.colors.value)
end

function Debug:HandleSlashCommand(command)
    if command == "debug" or command == "api" then
        DE:DebugWorldEvents()
        return true
    elseif command == "history" then
        if not DE:IsDebugEnabled() then
            DE:Print(DE:T("DE_SLASH_DEBUG_DISABLED"))
        else
            DE:DebugPrint("========== HISTORY START ==========")
            DE:DebugDiagnosticHistory(true)
            DE:DebugPrint("=========== HISTORY END ===========")
        end
        return true
    elseif command == "clearhistory" then
        DE:ClearDiagnosticHistory()
        DE:Print(DE:T("DE_SLASH_HISTORY_CLEARED"))
        return true
    elseif command == "testalert" then
        DE:ShowCenterChestAlert(DE:T("DE_CHEST_ALERT_TEST"))
        return true
    end
    return false
end


function Debug:PrintCommandHelp()
    DE:Print(DE:T("DE_SLASH_COMMANDS_DEBUG"))
end

function Debug:AppendSettingsControls(context)
    local chestHintControls = context.chestHintControls
    local diagnosticControls = context.diagnosticControls

    chestHintControls[#chestHintControls + 1] = {
        type = "button",
        name = DE:T("DE_SETTINGS_CHEST_TEST"),
        tooltip = DE:T("DE_SETTINGS_CHEST_TEST_TT"),
        func = function()
            DE:ShowCenterChestAlert(DE:T("DE_CHEST_ALERT_TEST"))
        end,
        disabled = context.chestWindowDisabled,
        width = "half",
    }

    diagnosticControls[#diagnosticControls + 1] = {
        type = "checkbox",
        name = DE:T("DE_SETTINGS_DEBUG_ENABLED"),
        tooltip = DE:T("DE_SETTINGS_DEBUG_ENABLED_TT"),
        default = DE.defaults.debugEnabled,
        getFunc = function() return DE.sv.debugEnabled end,
        setFunc = function(value) DE:SetDebugEnabled(value) end,
        disabled = context.disabledWhenOff,
        width = "full",
    }
    diagnosticControls[#diagnosticControls + 1] = {
        type = "checkbox",
        name = DE:T("DE_SETTINGS_DEBUG_AREA"),
        tooltip = DE:T("DE_SETTINGS_DEBUG_AREA_TT"),
        default = DE.defaults.showDebugArea,
        getFunc = function() return DE.sv.showDebugArea end,
        setFunc = function(value)
            DE.sv.showDebugArea = value
            context.updateStatusWindow()
        end,
        disabled = context.diagnosticDisabled,
        width = "full",
    }
    diagnosticControls[#diagnosticControls + 1] = {
        type = "description",
        text = DE:T("DE_SETTINGS_DEBUG_DESC"),
        width = "full",
    }
    diagnosticControls[#diagnosticControls + 1] = {
        type = "button",
        name = DE:T("DE_SETTINGS_DEBUG_DUMP"),
        func = function() DE:DebugWorldEvents() end,
        disabled = context.diagnosticDisabled,
        width = "half",
    }
    diagnosticControls[#diagnosticControls + 1] = {
        type = "button",
        name = DE:T("DE_SETTINGS_DEBUG_HISTORY"),
        func = function()
            DE:DebugPrint("========== HISTORY START ==========")
            DE:DebugDiagnosticHistory(true)
            DE:DebugPrint("=========== HISTORY END ===========")
        end,
        disabled = context.diagnosticDisabled,
        width = "half",
    }
    diagnosticControls[#diagnosticControls + 1] = {
        type = "button",
        name = DE:T("DE_SETTINGS_DEBUG_CLEAR"),
        warning = DE:T("DE_SETTINGS_DEBUG_CLEAR_WARN"),
        isDangerous = true,
        func = function()
            DE:ClearDiagnosticHistory()
            DE:Print(DE:T("DE_SLASH_HISTORY_CLEARED"))
        end,
        disabled = context.diagnosticDisabled,
        width = "half",
    }
end

DE:RegisterModule("debug", Debug)
