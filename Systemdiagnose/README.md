# 🩺 Windows-Systemdiagnose

Ein PowerShell-Skript zur **automatischen Erfassung wichtiger Windows-Diagnosedaten**. Es bündelt Systeminformationen, Treiberübersichten, Ereignisprotokolle und Diagnoseberichte in einer **ZIP-Datei mit Zeitstempel auf dem Desktop**.

Die Sammlung dient als Grundlage für die allgemeine **Systemanalyse, Dokumentation und Fehlerdiagnose** unter Windows 10 und Windows 11. Das Skript nimmt keine Änderungen an Systemeinstellungen vor und überträgt keine Diagnosedaten an Dritte.

## 🚀 Schnellstart

1. **PowerShell** über das Windows-Startmenü öffnen.
2. Den folgenden Befehl einfügen und mit **Enter** ausführen.
3. Eine eventuelle Nachfrage nach **Administratorrechten** bestätigen.
4. Nach Abschluss befindet sich das Diagnosearchiv auf dem **Desktop**.

```powershell
irm 'https://raw.githubusercontent.com/CelduinX/Tools/refs/heads/main/Systemdiagnose/Systemdiagnose.ps1' -OutFile "$env:TEMP\Systemdiagnose.ps1"; if ($?) { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\Systemdiagnose.ps1" }
```

> **Für Repository-Betreiber:** Vor der Veröffentlichung `DEIN-GITHUB-NAME` und `DEIN-REPO` ersetzen. Der Link setzt voraus, dass `Systemdiagnose.ps1` im öffentlichen Repository auf dem Branch `main` liegt.

**Was macht der Befehl?** `irm` (`Invoke-RestMethod`) lädt das PowerShell-Skript von GitHub herunter. Anschließend wird die heruntergeladene Datei lokal ausgeführt.

> ⚠️ **Sicherheit:** Skripte aus dem Internet nur aus vertrauenswürdigen Quellen ausführen. Den [Quellcode](./Systemdiagnose.ps1) vorab prüfen. `-ExecutionPolicy Bypass` gilt ausschließlich für den gestarteten PowerShell-Prozess.

## 📦 Enthaltene Diagnosedaten

| Bereich | Erfasste Informationen |
| --- | --- |
| **Systeminformationen** | Windows-Version, Hardware, CPU, Arbeitsspeicher, Grafikkarte, Audiogeräte, Laufwerke, BIOS |
| **Treiber** | Installierte Grafik- und Audiotreiber mit Versionsangaben |
| **Ereignisprotokolle** | Ausgewählte Windows-Protokolle der letzten **7 Tage** als `.evtx` |
| **Fehlerübersichten** | Fehler und Warnungen aus System- und Anwendungsprotokollen als `.csv` (maximal 500 je Protokoll) |
| **DxDiag** | DirectX-, Grafik- und Audiobericht als `.txt` |
| **MSInfo32** | Erweiterte Windows-Systeminformationen als `.txt` |
| **Zuverlässigkeit und Abstürze** | Zuverlässigkeitsereignisse und Metadaten vorhandener Windows-Fehlerberichte |
| **Sammlungsprotokoll** | Status und eventuelle Fehler der einzelnen Erfassungsschritte |

> **Hinweis:** Nicht alle Informationen sind auf jedem System verfügbar. Nicht erfolgreiche Erfassungsschritte werden protokolliert; die übrige Datensammlung wird fortgesetzt.

## 🗂️ Ausgabe

Die Ergebnisse werden automatisch als ZIP-Archiv auf dem vom System ermittelten Desktop gespeichert.

**Beispiel:**

```text
Systemdiagnose_2026-10-22_21-30-00.zip
```

Das Archiv enthält thematisch sortierte Unterordner und kann lokal ausgewertet oder bei Bedarf an eine vertrauenswürdige Supportperson weitergegeben werden. Eine **automatische Übertragung der Diagnosedaten findet nicht statt**.

## 🔒 Datenschutz

Die Berichte können unter anderem **Benutzernamen, Computernamen, Softwarelisten, Dateipfade, Geräteinformationen und protokollierte Fehlermeldungen** enthalten.

- Archiv **vor dem Weitergeben prüfen**.
- Diagnosearchive **nicht öffentlich** in Repositories, Issues oder Foren hochladen.
- Dateien nur an Personen senden, denen du vertraust.

## ⚙️ Voraussetzungen

- **Betriebssystem:** Windows 10 oder Windows 11
- **PowerShell:** Windows PowerShell 5.1 oder neuer
- **Internetverbindung:** Für den Download über den Schnellstart erforderlich
- **Administratorrechte:** Für eine vollständigere Datenerfassung empfohlen; das Skript fordert sie bei Bedarf an

### Alternative: Manuelle Ausführung

1. [`Systemdiagnose.ps1`](./Systemdiagnose.ps1) herunterladen.
2. PowerShell im Ordner der Datei öffnen.
3. Skript starten:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Systemdiagnose.ps1"
```

### Häufige Fragen

**Wo finde ich die ZIP-Datei?**  
Auf dem Desktop des ausführenden Windows-Benutzers. Bei einer Desktop-Umleitung (z. B. OneDrive) verwendet das Skript den von Windows gemeldeten Desktop-Pfad.

**Werden Windows-Einstellungen verändert?**  
Nein. Das Skript erfasst Informationen und erzeugt ein lokales Diagnosearchiv.

**Was passiert, wenn ein Bericht nicht erstellt werden kann?**  
Der Fehler wird im Sammlungsprotokoll festgehalten. Andere Erfassungsschritte werden nach Möglichkeit trotzdem abgeschlossen.

**Muss zusätzliche Software installiert werden?**  
Nein. Das Skript verwendet integrierte Windows- und PowerShell-Werkzeuge.

---

**Zweck:** Eine nachvollziehbare, weitgehend automatisierte Windows-Systemdiagnose in einem einzigen Archiv – ohne zusätzliche Installation.
