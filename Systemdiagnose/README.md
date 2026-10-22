# 🩺 Windows-Systemdiagnose

**Automatische Fehleranalyse für Windows 10 und Windows 11** – besonders hilfreich bei **Spiel-Freezes, Sound-Aussetzern, Treiberproblemen und Abstürzen**.

Das PowerShell-Skript sammelt wichtige Systeminformationen und Windows-Protokolle und speichert alles als **ZIP-Datei mit Zeitstempel direkt auf deinem Desktop**. Es verändert keine Systemeinstellungen.

## 🚀 Schnellstart (ein Befehl)

1. Öffne **PowerShell** über das Windows-Startmenü.
2. Kopiere den folgenden Befehl hinein und bestätige mit **Enter**.
3. Bestätige ggf. die Windows-Abfrage für **Administratorrechte**.
4. Nach Abschluss findest du die ZIP-Datei auf deinem **Desktop**.

> **Vor der Veröffentlichung anpassen:** `DEIN-GITHUB-NAME` und `DEIN-REPO` durch deinen GitHub-Benutzernamen und Repository-Namen ersetzen. Das Skript muss im **öffentlichen** Repository auf Branch `main` liegen.

```powershell
irm 'https://raw.githubusercontent.com/DEIN-GITHUB-NAME/DEIN-REPO/main/Systemdiagnose.ps1' -OutFile "$env:TEMP\Systemdiagnose.ps1"; if ($?) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\Systemdiagnose.ps1" }
```

**Was passiert?** `irm` (*Invoke-RestMethod*) lädt die Skriptdatei von GitHub herunter; anschließend wird sie ausgeführt. `itm` ist **kein** entsprechender Standardbefehl von PowerShell.

> 🔐 **Sicherheit:** Führe diesen Befehl nur aus, wenn du dem GitHub-Repository vertraust. Prüfe nach Möglichkeit zuerst den Quelltext in [`Systemdiagnose.ps1`](./Systemdiagnose.ps1). Die Option `-ExecutionPolicy Bypass` gilt nur für den gestarteten PowerShell-Prozess und ändert keine dauerhaften Windows-Einstellungen.

## 📦 Was wird gesammelt?

| Datei / Bereich | Inhalt |
| --- | --- |
| `Systeminformationen/Hardware_und_Windows.json` | Windows-Version, CPU, RAM, GPU, Audio, Speicherplatz, BIOS |
| `Systeminformationen/Grafik_Audio_Treiber.csv` | Installierte Grafik- und Audiotreiber inklusive Versionen |
| `Ereignisprotokolle/*.evtx` | Export der letzten **7 Tage**, etwa System-/Anwendungsfehler und Windows-Warnungen |
| `Ereignisprotokolle/*_Fehleruebersicht.csv` | Schnell lesbare Fehler- und Warnungsübersicht, maximal 500 Einträge je Protokoll |
| `Berichte/DxDiag.txt` | DirectX-, Grafik- und Audiobericht |
| `Berichte/MSInfo32.txt` | Erweiterte Windows-Systeminformationen |
| `Abstuerze/*.csv` | Zuverlässigkeitsverlauf und Namen von Windows-Fehlerberichten (sofern verfügbar) |
| `Sammlungsprotokoll.txt` | Übersicht erfolgreicher und fehlgeschlagener Sammelschritte |

Einzelne Berichte können je nach Windows-Konfiguration, Berechtigungen oder verfügbaren Ereignisprotokollen fehlen. **Fehlgeschlagene Schritte werden protokolliert; die übrige Analyse läuft weiter.**

## 🗂️ Ergebnis auf dem Desktop

Beispiel für den Dateinamen:

```text
Systemdiagnose_2026-10-22_21-30-00.zip
```

Die ZIP kann anschließend an eine **vertrauenswürdige Person für die Fehleranalyse** gesendet werden. Das Skript lädt **keine Diagnosedaten** ins Internet hoch; es lädt lediglich das Skript von GitHub herunter.

## 🎮 Hinweis bei Spiel- und Streaming-Problemen

Um Sound-Aussetzer und Freezes besser einzugrenzen, notiere zusätzlich:

- **Welches Spiel** ist betroffen – eines oder mehrere?
- Tritt der Fehler **auch ohne OBS / Streaming** auf?
- **Ungefähre Uhrzeit** eines Aussetzers (wichtig zum Abgleich der Ereignislogs).

Die Diagnose ist eine Momentaufnahme und misst **keine Live-Frametimes oder DPC-Latenzen**.

## 🔒 Datenschutz

⚠️ Die ZIP kann **Benutzernamen, Computernamen, installierte Programme, Dateipfade, Hardwaredetails und Inhalte aus Windows-Ereignisprotokollen** enthalten. **Nicht öffentlich** in GitHub-Issues, Discord-Kanälen oder Cloud-Freigaben posten. Teile sie nur privat mit Personen, denen du vertraust, und prüfe die Daten vorher.

## 🛠️ Voraussetzungen und Fehlerbehebung

- **Betriebssystem:** Windows 10 oder 11, PowerShell 5.1 oder neuer.
- **Internet:** Nur zum Herunterladen des Skripts erforderlich.
- **Administratorrechte:** Empfohlen; das Skript fordert sie selbst an. Wenn sie abgelehnt werden, läuft die Sammlung eingeschränkt weiter.
- **Befehl lädt nicht:** Prüfe, ob das Repository öffentlich ist, beide Platzhalter ersetzt sind und die Datei auf `main` liegt. Bei anderem Branchnamen den Link anpassen.
- **Datei erscheint nicht:** Prüfe die angezeigte Fehlermeldung. Der Desktop kann z. B. über OneDrive umgeleitet sein; das Skript nutzt den von Windows gemeldeten Desktop-Pfad.

### Alternativ: Manuell starten

1. Lade [`Systemdiagnose.ps1`](./Systemdiagnose.ps1) herunter.
2. Öffne im Downloadordner PowerShell.
3. Starte:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Systemdiagnose.ps1"
```

---

**Ziel:** Wichtige Windows-Diagnosedaten in einer einzigen, zeitgestempelten ZIP-Datei bündeln – ohne zusätzliche Softwareinstallation.
