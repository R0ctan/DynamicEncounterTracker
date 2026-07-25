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

## 0. Offener Bug — Dev-Build friert bei Reload mit aktivem Encounter ein (nicht gelöst, 2026-07-26)

- **Symptom:** `/reloadui` im **Dev-Build**, während bereits ein Dynamic Encounter aktiv läuft, führt zu einem kompletten Client-Freeze (nur Hard-Kill half). Bestätigt reproduzierbar.
- **Eingrenzung (bestätigt durch Tests):**
  - Prod-Build: Reload bei aktivem Encounter lädt sauber. Kein Hang.
  - Dev-Build: Reload **ohne** aktiven Encounter lädt sauber. Kein Hang.
  - Dev-Build: Reload **mit** aktivem Encounter → Hang.
  - Daraus folgt: Der Fehler liegt im Zusammenspiel aus Dev-Modul-Code (`dev/DynamicEncounterTracker_Debug.lua` und/oder `dev/DynamicEncounterTracker_RespawnMeasurement.lua`) und dem Erkennungs-/Aktivierungspfad, der beim ersten periodischen Scan nach dem Reload läuft (`ScanActiveWorldEvents` → `SetActiveState` → `RecordEncounterActivation`/`StartStepRun` → `ObserveWorldEventStep`/`RefreshMapLocationPhase`).
- **Bereits geprüft, kein Befund:** Vollständige Zeile-für-Zeile-Durchsicht beider Dev-Module (Stand 2026-07-26) auf Endlosschleifen, Rekursion in `ModuleHook`/`DebugHook`, unbegrenztes Tabellenwachstum. Alle Schleifen laufen über endliche Tabellen (`pairs`/`ipairs`) oder haben eine klare Abbruchbedingung (`while #x > N do table.remove(x,1) end`). Keine der geprüften Stellen erklärt einen zwingenden Hang.
- **Status:** Zurückgestellt, kein Diagnose-Dump gebaut. Dev-Build wird nicht an Endnutzer verteilt (nur lokales Diagnosewerkzeug) — daher kein Release-Blocker für 1.0.0, aber vor jeder eigenen Dev-Nutzung mit aktivem Encounter beachten: **vor `/reloadui` bei laufendem Encounter erst den Encounter beenden/verlassen, oder Prod-Build nutzen.**
- **Nächster Schritt bei Wiederaufnahme:** gezielter Mini-Dump vor den o. g. kritischen Funktionen (Markierung in Chat/Datei, die auch bei Freeze vor dem Hang geschrieben wird), dann erneut reproduzieren.

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

### Lua-Language-Server: need-check-nil bei paarweise korrelierten Feldern
- **Was:** Muster `xExactFlag and xTimestamp` (z. B. `runtime.lastStartExact and runtime.lastStartAt`) als Guard vor einem arithmetischen Zugriff auf `xTimestamp`. Der LS meldet `need-check-nil` auf dem Timestamp-Feld, obwohl das Flag genau dann `true` ist, wenn der Timestamp gesetzt wurde (beide werden immer im selben Atemzug zugewiesen, siehe `RecordEncounterActivation`/`RecordEncounterDeactivation` in `dev/DynamicEncounterTracker_RespawnMeasurement.lua`).
- **Warum kein Fix:** Der LS verifiziert keine Korrelation zwischen zwei unabhängigen Table-Feldern über eine `and`-Kette hinweg — das ist eine strukturelle Grenze der statischen Analyse, kein echtes nil-Risiko. Ein Fix (z. B. zusätzlicher `type(x)=="number"`-Check) wäre reine Linter-Beschwichtigung ohne Laufzeitnutzen.
- **Regel:** Bei diesem Muster geprüft dokumentieren statt Code verbiegen. Neu auftretende `need-check-nil`-Meldungen auf demselben Muster (Flag+Timestamp-Paar) einzeln gegen die tatsächliche Zuweisungshistorie des Feldes prüfen, bevor ein Guard ergänzt wird.
- **Wichtig zur Direktiven-Platzierung:** Bei `if A and B then ... end`-Konstrukten meldet der LS `need-check-nil` sowohl auf der `if`-Zeile selbst (Zugriff auf `B` innerhalb der `and`-Kette) als auch — unabhängig davon — auf jeder späteren Verwendung von `B` im Then-Block. Das sind zwei getrennte Diagnostic-Instanzen, keine verschobene Meldung derselben Stelle. Beide brauchen eine eigene `---@diagnostic disable-line`/`disable-next-line`, sonst bleibt eine der beiden im Problems-Panel sichtbar (in der Praxis geprüft: `disable-next-line` vor der `if`-Zeile UND `disable-line` am Ende der Verwendungszeile im Block).

### Lua-Language-Server: need-check-nil/param-type-mismatch bei Schleifenzähler-Korrelation
- **Was:** Muster: `local x = nil; local counter = 0; for _ in pairs(t) do if cond then counter = counter + 1; x = value end end; if counter ~= 1 then return end; use(x)`. Der LS kann nicht nachvollziehen, dass `counter == 1` bedeutet, dass `x` in genau dieser einen Schleifeniteration gesetzt wurde. Beispiel: `DE:_DebugGetStableLearnedSequence`/`_DebugGetStableLearnedLocationSequence` in `dev/DynamicEncounterTracker_Debug.lua` (`variants`-Zähler korreliert mit `signature`-Variable vor `string.gmatch(signature, ...)`).
- **Verwandtes Muster:** Zwei getrennte `if`-Blöcke, die dieselbe Bedingung prüfen (z. B. `local x = cond and f() or nil` gefolgt später von `if cond then use(x) end`) — der LS korreliert die beiden Bedingungen nicht, obwohl `x` dadurch garantiert non-nil ist. Beispiel: `respawnTiming` in `DE:DebugWorldEvents` (`dev/DynamicEncounterTracker_Debug.lua`), abgesichert durch dieselbe `self.state.eventData`-Prüfung wie bei der Zuweisung.
- **Regel:** Gleiche Behandlung wie beim Flag+Timestamp-Muster oben — Einzelbewertung, bei bestätigtem False Positive zeilengenaue Direktive statt Code-Verbiegung.

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

**Phase-8-Ergebnis (2026-07-26): weiterhin unklar, nicht verifiziert.** Der reguläre Ingame-Testdurchlauf bestätigte die implementierten Bedingungen (Kiste 1 bei Step 32→33, Kiste 2 bei Encounterende Step 35) als funktionierend, aber Step 31/34 wurden dabei nicht gezielt beobachtet. Bleibt offener Verifikationspunkt für einen künftigen Durchlauf — Code bleibt bis dahin unverändert (keine Alternativbedingungen ergänzen ohne Bestätigung).

## 5. Optionsmatrix / Konfliktregeln

<!-- Welche Regel gewinnt bei Options-Kombinationen. Wird bei jeder neuen Option ergänzt. -->

| Situation / Kombination | Erwartetes Verhalten | Regelbegründung |
|---|---|---|
| `showRespawnTimer=false` + `showSpawnWindowHint`/`showRespawnOverrun` beliebig | Nur generischer Cooldown-Text, keine Phasenanzeige | Timer-Sichtbarkeit ist übergeordnet — ohne Timer keine Timer-Unterphasen |
| `showChestHints=false` + `showCenterChestAlert=true` | Kein Center-Alert trotz aktivierter Einzeloption | Kisten-Gesamtschalter schlägt den spezifischeren Center-Alert-Schalter |
| `debugEnabled=false` + `showDebugArea=true` | Debug-Zeilen zeigen `-`, keine Berechnung läuft | Berechnung (debugEnabled) ist der Gate für showDebugArea, nicht umgekehrt |

Vollständige Matrix mit allen geprüften Settings-Interaktionen und Grenzfällen: siehe Phase-3-Review (Commit-Historie 2026-07-25) bzw. FINALIZE.md-Ablauf dieses Projekts.

### Ungetesteter Codepfad: mehr als eine Encounter-Config pro Zone
Alle drei konfigurierten Zonen (Steinfälle, Glenumbra, Auridon) haben genau eine Config pro Zone. Der Mehrfach-Config-Pfad (`#configs > 1` in `UpdateCurrentZone`/`ScanActiveWorldEvents`) existiert im Code, wird aber mit der aktuellen Config nie durchlaufen.

**Phase-8-Ergebnis (2026-07-26): bewusst nicht getestet, nicht "nicht erreichbar" bestätigt.** Der Testversuch wurde ausgelassen, nicht durchgeführt und gescheitert — der Unterschied ist wichtig: Der Pfad könnte technisch auslösbar sein, wurde aber nicht geprüft. Bleibt als offener, zurückgestellter Testpunkt für einen künftigen Durchlauf (siehe Ideenliste unten), nicht als abgeschlossen behandeln.

## 6. Sprachdatei-Konventionen

<!-- Key-Namensschema, Platzhalter-Konventionen, Fallback-Regel. -->

## 7. Release-Erkenntnisse

<!-- Alles rund um ESOUI, Minion, ZIP, Versionierung, das beim ersten Mal Zeit gekostet hat. -->

### CODEX_HANDOVER.md — endgültig verworfen (Phase 6, 2026-07-25)
Entscheidung: Datei bleibt in `_trash/DynamicEncounterTracker/` und geht mit dessen manueller Leerung; kein Zurückholen. `docs/KNOWLEDGE.md` ist der eine gepflegte Wissensort; ein Übergabetext lässt sich bei Bedarf jederzeit aktuell aus KNOWLEDGE + AGENTS.md generieren, ein gepflegtes Duplikat würde nur erneut veralten.

### Test-Mindestkatalog vor Übergabe/Release (aus CODEX_HANDOVER)
Syntax (`texluac -p`), Produktiv-/Dev-Manifest-Trennung, Mocks mit/ohne Dev-Module, Settings in beiden Varianten, Config-Standards aller Encounter, Cooldown→Spawnfenster→Überschreitung, `MM:SS`-Parser + ungültige Werte, Reset auf Defaults, Addon aus/an in unterstützter/nicht unterstützter Zone, keine Kistenmeldung ohne Config-Regel, String-ID-Referenzen gegen `lang/default.lua`, ZIP-Struktur. Live zusätzlich: LAM-Editboxen, Settings-Änderung im laufenden Cooldown, Übergänge exakt an den Zeitgrenzen, mehrminütige Überschreitung. SavedVariables des Vorgängers `DynamicEncounter` haben einen anderen Namen — kein Übernahmepfad, Neustart mit Defaults ist korrekt.

### Phase-8-Ingame-Testdurchlauf 1.0.0 — Ergebnis (2026-07-26)
Vollständiger Durchlauf des Testplans (`docs/local/PHASE8_TESTPLAN_1.0.0.md`) mit Ergebnis: alle Kernfunktionen bestätigt (Stonefalls/Glenumbra/Auridon-Kistenlogik, Respawn-Timing exakt wie konfiguriert per Debug-Dump verifiziert, Reload-/Zonenwechsel-Grenzfälle, Optionsmatrix-Konfliktregeln, Lokalisierung, Prod-Build). Drei Punkte bewusst zurückgestellt statt getestet, siehe §0/§4/§5 und Ideenliste: der Dev-Reload-Freeze-Bug, die Auridon-Alternativbedingungen, der Mehrfach-Config-Pfad. Screenshot für ESOUI_DESCRIPTION steht noch aus (wird vor dem eigentlichen Release nachgeholt, kein Testplan-Fail).

### CHANGELOG-Konsolidierung beim Release (Phase-9-Punkt, festgehalten in Phase 7)
Beim Release wird die „Unreleased"-Sektion in den 1.0.0-Abschnitt konsolidiert. Rein interne Punkte ohne je veröffentlichten Vorzustand (z. B. der SavedVars-Rename `DynamicEncounterTrackerSavedVariables` → `DynamicEncounterTracker_Data`) entfallen im öffentlichen Changelog ersatzlos — es gab nie einen Endnutzer, der die alte Bezeichnung kannte. Erster öffentlicher Eintrag lautet „1.0.0 — Initial release" mit der Feature-Liste, nicht mit internen Umbenennungen.

## 8. Ideenliste / Nächste Version

<!-- Features und Verbesserungen, die während Freeze/Entwicklung anfielen, aber bewusst verschoben wurden. -->

| Idee | Quelle/Anlass | Priorität |
|---|---|---|
| TD-002: `Initialize()` in Migrate/Normalize/Bootstrap aufteilen (`MigrateSavedVariables()` + `NormalizeSavedVariables()` + Modul-/UI-Bootstrap; EnsureTable/EnsureNumberInRange/…-Helfer; keine blinde rekursive Generalreparatur — die bestehende explizite Validierung ist funktional und darf nicht durch eine riskantere Kurzlösung ersetzt werden) — zurückgestellt für v1.1 wegen Feature Freeze, nicht kurz vor Release an einer funktionierenden Funktion anfassen | TECHNICAL_DEBT, Status „Vorgemerkt"; bestätigt im Phase-2-Review 2026-07-25 | mittel |
| Bug: Dev-Build friert bei `/reloadui` mit aktivem Encounter komplett ein (siehe §0). Ursache nicht gefunden, Diagnose-Dump als nächster Schritt vorgesehen. Kein Release-Blocker (Dev-Build nicht öffentlich), aber vor v1.1 klären | Phase-8-Test 2026-07-26 | mittel |
| Auridon-Alternativbedingungen Step 31/34 gezielt beobachten (siehe §4) — bisher nie bewusst geprüft, weder bestätigt noch widerlegt | Phase-8-Test 2026-07-26 | niedrig |
| Mehrfach-Config-Pfad (`#configs > 1`) gezielt zu provozieren versuchen (siehe §5) — bisher nicht einmal ein Versuch unternommen | Phase-8-Test 2026-07-26 | niedrig |
| B5: `showPhase`-Prüfung zentralisieren (aktuell zwei identische Prüfstellen: Zeilen-Sichtbarkeit in `RefreshWindowLayout` und Text-Fallback in `GetCurrentSectionText`) — bewusste Feature-Freeze-Ausnahme von der Zentralisierungs-Faustregel, kein Bug, nur Redundanz | Phase-3-Review 2026-07-25 | niedrig |
| Gamepad-Unterstützung fehlt vollständig (keine `IsInGamepadPreferredMode()`-Anpassung) — als bekannte Einschränkung in README/ESOUI_DESCRIPTION dokumentieren (Phase 7), keine Umsetzung vor 1.0.0 | Phase-3-Review 2026-07-25 | niedrig |
| Minimode: minimales Fenster mit sehr kompakter Darstellung als Alternative zum normalen Statusfenster. Details (welche Infos bleiben sichtbar, Umschaltung, eigenes Layout vs. Skalierung) noch offen, für 1.0.x nach Feature Freeze zu konzipieren | Thomas, 2026-07-26 | mittel |

**TD-001:** erledigt, siehe Abschnitt 4. **TD-003/TD-004:** im Phase-2-Review 2026-07-25 bestätigt als bewusst akzeptierte, unveränderte Einschränkungen (Scanintervall 1000 ms bleibt ohne Profiling-Beleg; kein UI-String-/Farbcache ohne Profiling-Beleg) — kein Umsetzungsbedarf, nicht erneut aufgreifen ohne neue Messdaten.
