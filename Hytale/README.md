# Hytale auf Deutsch

Mit diesem PowerShell-Einzeiler werden die deutschen Sprachdateien für Hytale automatisch heruntergeladen und installiert.

## Installation

1. Hytale vollständig schließen.
2. Mit der rechten Maustaste auf das Windows-Startmenü klicken und **Terminal (Administrator)** auswählen.
3. Den folgenden Befehl vollständig kopieren, in das Terminal einfügen und mit `Enter` ausführen:

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1|iex
```

Danach Hytale normal starten.

## Was macht der Befehl?

Das aufgerufene Installationsskript:

- lädt `Hytale Language German v1.5.zip` direkt aus diesem GitHub-Repository herunter,
- prüft die heruntergeladene ZIP-Datei per SHA-256,
- entpackt die ZIP-Datei in einen zufälligen temporären Ordner,
- erkennt den enthaltenen `install`-Ordner,
- kopiert dessen vollständigen Inhalt nach `%APPDATA%\Hytale\install`,
- ersetzt dort bereits vorhandene Dateien mit gleichem Namen und
- löscht die temporären Dateien anschließend wieder.

Andere Dateien im Hytale-Verzeichnis werden nicht gelöscht.

## Installationspfad

Die Sprachdateien landen unter:

```text
%APPDATA%\Hytale\install\release\package\game\latest\Client\Data\Shared\Language
```

Der genaue Benutzerpfad ist normalerweise:

```text
C:\Users\DEIN-NAME\AppData\Roaming\Hytale\install
```

## Aktualisieren oder erneut installieren

Den Einzeiler einfach erneut ausführen. Vorhandene Sprachdateien mit gleichem Namen werden überschrieben.

## Hinweise

- Nur unter Windows mit PowerShell verwenden.
- Hytale vor der Installation vollständig beenden, damit keine Dateien gesperrt sind.
- Die Übersetzung ist ein Community-Projekt und keine offizielle Hytale-Veröffentlichung.
