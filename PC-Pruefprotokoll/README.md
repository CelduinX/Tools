# PC-Prüfprotokoll

Dieses portable Werkzeug prüft einen Windows-10- oder Windows-11-PC und erzeugt ein druckbares HTML-Protokoll sowie JSON-Rohdaten. Es installiert, repariert oder verändert nichts am geprüften System.

Die Dateien dieses Ordners müssen für die Verwendung gemeinsam heruntergeladen und unverändert im selben Verzeichnis abgelegt werden.

## Direktstart über PowerShell

PowerShell öffnen und folgenden Befehl ausführen:

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/PC-Pruefprotokoll/install.ps1|iex
```

Der Bootstrap lädt das aktuelle Prüfskript temporär von GitHub, startet es und entfernt die temporäre Kopie nach dem Lauf wieder.

## Manueller Download

1. Laden Sie das Repository über **Code → Download ZIP** herunter.
2. Entpacken Sie das ZIP-Archiv.
3. Öffnen Sie darin den Ordner `PC-Pruefprotokoll`.

## Verwendung

1. Kopieren Sie den gesamten Ordner auf den zu prüfenden PC.
2. Starten Sie `PC-Pruefung-starten.cmd` per Doppelklick.
3. Bestätigen Sie die Windows-Abfrage für Administratorrechte.
4. Geben Sie die durchgeführten Tätigkeiten einzeln ein. Eine leere Eingabe beendet die Erfassung und startet die Prüfung.
5. Warten Sie, bis sich das Prüfprotokoll im Standardbrowser öffnet.
6. Drucken Sie den Bericht mit `Strg+P` oder wählen Sie im Druckdialog „Als PDF speichern“.

Die Ergebnisse werden in einem datierten Ordner auf dem Desktop abgelegt:

```text
PC-Pruefprotokoll_<Computername>_<Datum_Uhrzeit>\
├── PC-Pruefprotokoll.html
└── Pruefdaten.json
```

## Hinweise

- Der übliche Prüflauf dauert je nach Windows-Update-Suche und Internetverbindung etwa 3–8 Minuten.
- Für die Verbindungstests werden `cloudflare.com` und der öffentliche Cloudflare-DNS-Server `1.1.1.1` verwendet.
- Der Bericht enthält Geräte-, Serien-, MAC- und IP-Daten, jedoch keine Produktschlüssel, Kennwörter oder WLAN-Schlüssel.
- Die eingegebenen Tätigkeiten erscheinen als Stichpunktliste im HTML-Bericht und werden zusätzlich in den JSON-Rohdaten gespeichert.
- Nicht unterstützte oder nicht zuverlässig auslesbare Werte werden als „Nicht verfügbar“ dokumentiert.
- Der Bericht ist eine technische Momentaufnahme und keine Garantie für zukünftige Fehlerfreiheit.

## Direkter Aufruf für Tests

Das Skript kann auch aus einer PowerShell-Konsole gestartet werden:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\PC-Pruefung.ps1
```

Die internen Schalter `-SkipElevation`, `-NoOpen` und `-NoActivityPrompt` ermöglichen einen nicht erhöhten, automatisierten Testlauf. Mit `-OutputRoot <Pfad>` kann dafür ein abweichender Ausgabeordner verwendet werden.

Tätigkeiten können für automatisierte Abläufe auch direkt übergeben werden:

```powershell
.\PC-Pruefung.ps1 `
  -Activities @("Windows eingerichtet", "Treiber installiert") `
  -NoActivityPrompt
```
