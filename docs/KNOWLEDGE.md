# KNOWLEDGE.md — DynamicEncounterTracker

> **Zweck:** Zentrale, dauerhafte Wissenssammlung des Projekts. Hier landet
> alles, was beim nächsten Mal Zeit spart: ESO-API-Erkenntnisse, Workarounds,
> bewährte Patterns, Entscheidungen. Einträge werden **sofort** bei
> Erkenntnisgewinn ergänzt (siehe `shared-tools/standards/ENTWICKLUNGSREGELN.md`,
> Regel A.5).
>
> **Zwei Ebenen:**
> - Projekt-`docs/KNOWLEDGE.md` (diese Datei): projektspezifische
>   Entscheidungen und Eigenheiten.
> - Zentrale Wissensdatenbank `_reference\_knowledge\` (neben den Addon-Repos):
>   alles, was für mehrere Addons gilt, als eigene Themendatei. Bei jedem
>   Finalize (FINALIZE.md Phase 6) abgleichen.
>
> **Regeln für Einträge:**
> - Kurz, konkret, mit Codebeispiel wo sinnvoll. Kein Prosa-Tutorial.
> - Jeder Eintrag beantwortet: *Was? Warum? Wie verwenden?*
> - Veraltete Einträge löschen oder als veraltet markieren — keine Leichen.

---

## 1. ESO-API-Erkenntnisse

<!-- Verhalten der API, das nicht offensichtlich oder nicht dokumentiert ist. Format: Was? / Warum wichtig? / Lösung (mit Codebeispiel). -->

### Keine nutzbare Open-World-Instanzkennung
- **Was:** ESO liefert keine verlässliche Kennung der Offene-Welt-Instanz.
- **Konsequenz:** Nach Port/Ladebildschirm/Zonenwechsel wird der Respawn-Timer bewusst verworfen (niemals Zeitmessung darüber hinweg verbinden); ein laufendes Event wird vom normalen Scan wieder erkannt.

### Teilnahme-API spiegelt nur momentane Nähe
- **Was:** `participation=false` bedeutet nur „gerade nicht beteiligt am aktuellen Abschnitt", nicht „war nie beteiligt".
- **Konsequenz:** Teilnahme wird pro `stepDefId` im aktuellen Lauf gespeichert; ein späteres `false` löscht erkannte Teilnahme nicht.

### Geprüfte World-Event-API (Audit Vorgängerprojekt 0.1.18–0.1.22, gegen ESOUI-Source/Doku)
- **Events:** `EVENT_WORLD_EVENTS_INITIALIZED`, `EVENT_WORLD_EVENT_ACTIVATED`/`_DEACTIVATED`, `EVENT_WORLD_EVENT_STEP_CHANGED`, `EVENT_WORLD_EVENT_STEP_PROGRESS_CHANGED`, `EVENT_WORLD_EVENT_PARTICIPATION_BEGIN`/`_END`.
- **Kernfunktionen:** `GetNextWorldEventInstanceId`, `GetWorldEventId`, `GetWorldEventType`, `GetParticipatingWorldEventStep`, `GetWorldEventCurrentStepProgress`, `GetWorldEventStepName`, `GetWorldEventStepDescription`, `GetWorldEventLocationContext`, `GetWorldEventPOIInfo`; POI-Zuordnung über `GetPOIWorldEventInstanceId(zoneIndex, poiIndex)`.
- **Referenz-Muster:** Iteration wie im ESOUI-Weltkarten-Code; Teilnahmephase wie ZOS' eigener Tracker `esoui/ingame/dynamicevents/dynamiceventstracker.lua`.
- Map-Location-Tooltip-APIs (`GetMapLocationTooltipHeader` etc.) nur als lokalisierter Fallback.
- Bei neuer APIVersion erneut gegenprüfen.

### Mehrfach vorkommende Step-IDs in Step-Sequenzen
- **Was:** Dieselbe Step-ID kann mehrfach in einer Encounter-Sequenz auftreten (z. B. Glenumbra: Step 18 fünfmal).
- **Lösung:** Position anhand Verlauf/Vorgänger einordnen; wenn nicht sicher, `?/y` anzeigen und nicht raten.

## 2. Workarounds

<!-- Bewusste Umgehungen von Engine-/API-Problemen. Immer mit Grund, damit sie später entfernt werden können, wenn das Problem behoben ist. -->

## 3. Bewährte Patterns

<!-- Wiederverwendbare Lösungsmuster. Kandidaten für NextTryShared / Template markieren mit [LIB]. -->

### Typ-sichere SavedVariables-Reparatur
- **Was:** `self.sv.size = self.sv.size or {}` schützt nur gegen `nil`/`false`, nicht gegen falschen Datentyp (z. B. String).
- **Regel:** Verschachtelte Strukturen ausdrücklich mit `type(x) ~= "table"` prüfen und bei Bedarf eine neue, unabhängige Standardstruktur anlegen (keine gemeinsame Referenz aus den Defaults wiederverwenden).

## 4. Architekturentscheidungen

<!-- Bewusste Entscheidungen mit Begründung, damit sie später nicht versehentlich rückgängig gemacht werden. Format: Entscheidung / Grund / Konsequenz. -->

### Verbindliche Entwicklungsregeln (aus CODEX_HANDOVER, Stand 2026-07-25)
1. Zonen-/Encounterunterschiede ausschließlich über `_Config.lua` modellieren — keine Funktionen wie `CheckStonefallsChest()`.
2. Keine sichtbaren Eventnamen/Step-Texte hardcoden — sie kommen lokalisiert aus der ESO-API; eigene Texte nur über String-IDs (Präfix `DE_`, bewusst beibehalten).
3. **Kistenlogik hart:** Ohne explizite `chestRules` keine Kistenprüfung und keine Kistenmeldung — kein heuristischer Fallback. Jede Kistenregel prüft ihren konkreten Teilnahme-Step; „Teilnahme erkannt" heißt nicht automatisch Berechtigung für jede Kiste.
4. Produktivversion funktioniert vollständig ohne Dev-Module; Messreihen/Statistik/Respawn-Testbefehle bleiben Dev-only (Dev/Prod-Split über shared-tools, siehe `shared-tools/AGENTS.md`).
5. Debug aus = keine Debugberechnung; Addon aus = keine Runtime-Arbeit; außerhalb unterstützter Zonen keine Encounter-Pollinglast (nur leichte Zonen-/Ladeerkennung).
6. Respawn-Settings-Änderung während laufendem Cooldown: `earliestRespawnAt`/`respawnAt` vom ursprünglichen `cooldownStartedAt` neu berechnen; erwarteter Start nie vor frühestem Start.
7. Live-Erfolg nicht behaupten, solange nur Syntax-/Mocktests erfolgt sind.
8. Neue produktive Settings-Controls immer mit Tooltip; neue Submenus immer mit `description`-Block am Anfang (Settings-Konvention nach Stickerbook+-Muster, seit 2026-07-24).

### Hinweispriorität im Statusfenster
1. aktive Kistenmeldung → 2. Spawnfenster-/Überschreitungshinweis im Cooldown → 3. lokalisierter ESO-Zusatzhinweis im aktiven Event → 4. `-`.

### Bewusst hartkodierte Debug-Statuszeilen (Dev-Modul)
`GetDetectionText`/`GetParticipationDebugText`/`GetApiDebugText`/`GetTestDebugText` in `dev/DynamicEncounterTracker_Debug.lua` sowie die einzelne Log-Zeile `"Die API meldet derzeit keine aktive World-Event-Instanz."` in `DebugWorldEvents()` nutzen hartkodierten Text statt String-IDs — bewusst so (reines Dev-Werkzeug, nur sichtbar via `/dynet debug`, nie im Produktionspaket). Falls doch lokalisiert wird: neue String-IDs anlegen (die früheren Kandidaten `DE_DEBUG_CHEST_NOT_CONFIGURED`/`DE_DEBUG_CHEST_FIXED`/`DE_SLASH_DEBUG_UNAVAILABLE` wurden am 2026-07-25 als dauerhaft ungenutzt aus allen 6 Sprachdateien entfernt, siehe Phase-2-Review).

### TD-001 — erledigt (Phase-2-Review, 2026-07-25)
Die im technischen Backlog vorgeschlagene Diagnose unbekannter World-Event-IDs ist bereits umfassend im Debug-Modul umgesetzt und geht über den ursprünglichen Vorschlag hinaus: `DebugWorldEventInstance` (pro Instanz: Typ, Location-Context, Rolle, Progress/Expire mit pcall-Absicherung), `DebugCurrentZoneWorldEventPOILinks` (POI-Verknüpfung), sowie die vollständige Step-/Map-Location-Lernlogik (`_DebugFinalizeStepRun`, `GetStableLearnedSequence`) mit dedupliziertem, zonenweise gespeichertem Verlauf. Alles ausschließlich im Dev-Build, keine Produktionsmeldung, kein Tracking-Fallback. Kein weiterer Umsetzungsbedarf.

### Unbestätigte Encounter-Bedingungen nicht ergänzen
Auridon: Step 31 als Alternativbedingung für Kiste 1 und Step 34 für Kiste 2 sind NICHT bestätigt — erst nach gezieltem Live-Test ergänzen. Live-Messwerte der Respawn-Zeiten (Steinfälle 33:00, Glenumbra 30:11, Auridon 31:02/31:01) sind als Config-Standards hinterlegt.

## 5. Optionsmatrix / Konfliktregeln

<!-- Welche Regel gewinnt bei Options-Kombinationen. Wird bei jeder neuen Option ergänzt. -->

| Situation / Kombination | Erwartetes Verhalten | Regelbegründung |
|---|---|---|

## 6. Sprachdatei-Konventionen

<!-- Key-Namensschema, Platzhalter-Konventionen, Fallback-Regel. -->

## 7. Release-Erkenntnisse

<!-- Alles rund um ESOUI, Minion, ZIP, Versionierung, das beim ersten Mal Zeit gekostet hat. -->

### Test-Mindestkatalog vor Übergabe/Release (aus CODEX_HANDOVER)
Syntax (`texluac -p`), Produktiv-/Dev-Manifest-Trennung, Mocks mit/ohne Dev-Module, Settings in beiden Varianten, Config-Standards aller Encounter, Cooldown→Spawnfenster→Überschreitung, `MM:SS`-Parser + ungültige Werte, Reset auf Defaults, Addon aus/an in unterstützter/nicht unterstützter Zone, keine Kistenmeldung ohne Config-Regel, String-ID-Referenzen gegen `lang/default.lua`, ZIP-Struktur. Live zusätzlich: LAM-Editboxen, Settings-Änderung im laufenden Cooldown, Übergänge exakt an den Zeitgrenzen, mehrminütige Überschreitung. SavedVariables des Vorgängers `DynamicEncounter` haben einen anderen Namen — kein Übernahmepfad, Neustart mit Defaults ist korrekt.

## 8. Ideenliste / Nächste Version

<!-- Features und Verbesserungen, die während Freeze/Entwicklung anfielen, aber bewusst verschoben wurden. -->

| Idee | Quelle/Anlass | Priorität |
|---|---|---|
| TD-002: `Initialize()` in Migrate/Normalize/Bootstrap aufteilen (`MigrateSavedVariables()` + `NormalizeSavedVariables()` + Modul-/UI-Bootstrap; EnsureTable/EnsureNumberInRange/…-Helfer; keine blinde rekursive Generalreparatur — die bestehende explizite Validierung ist funktional und darf nicht durch eine riskantere Kurzlösung ersetzt werden) — zurückgestellt für v1.1 wegen Feature Freeze, nicht kurz vor Release an einer funktionierenden Funktion anfassen | TECHNICAL_DEBT, Status „Vorgemerkt"; bestätigt im Phase-2-Review 2026-07-25 | mittel |
| Vor dem Leeren von `_trash` entscheiden: `CODEX_HANDOVER.md` als lebendes Dokument zurückholen oder endgültig verwerfen (Regeln sind nach KNOWLEDGE extrahiert, das Dokument war aber auf aktuellem Stand) | Bestandsaufnahme 2026-07-25 | niedrig |

**TD-001:** erledigt, siehe Abschnitt 4. **TD-003/TD-004:** im Phase-2-Review 2026-07-25 bestätigt als bewusst akzeptierte, unveränderte Einschränkungen (Scanintervall 1000 ms bleibt ohne Profiling-Beleg; kein UI-String-/Farbcache ohne Profiling-Beleg) — kein Umsetzungsbedarf, nicht erneut aufgreifen ohne neue Messdaten.
