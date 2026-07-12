# Hytale auf Deutsch

Mit diesem PowerShell-Einzeiler werden die deutschen Sprachdateien für Hytale automatisch heruntergeladen und installiert.

## Installation

1. Hytale vollständig schließen.
2. PowerShell öffnen. Administratorrechte sind normalerweise nicht erforderlich.
3. Den folgenden Befehl vollständig kopieren, in PowerShell einfügen und mit `Enter` ausführen:

```powershell
$u='https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/Hytale%20Language%20German%20v1.5.zip';$z=Join-Path $env:TEMP ('hytale-de-'+[guid]::NewGuid()+'.zip');$x=Join-Path $env:TEMP ('hytale-de-'+[guid]::NewGuid());try{Invoke-WebRequest -Uri $u -OutFile $z -UseBasicParsing;Expand-Archive -LiteralPath $z -DestinationPath $x -Force;$s=@(Get-ChildItem -LiteralPath $x -Directory -Recurse | Where-Object Name -eq 'install');if($s.Count-ne 1){throw "Erwartet wurde genau ein install-Ordner, gefunden: $($s.Count)"};$d=Join-Path $env:APPDATA 'Hytale\install';New-Item -ItemType Directory -Path $d -Force|Out-Null;Get-ChildItem -LiteralPath $s[0].FullName -Force|Copy-Item -Destination $d -Recurse -Force;Write-Host 'Hytale wurde erfolgreich auf Deutsch umgestellt.' -ForegroundColor Green}finally{Remove-Item -LiteralPath $z,$x -Recurse -Force -ErrorAction SilentlyContinue}
```

Danach Hytale normal starten.

## Was macht der Befehl?

Der Einzeiler:

- lädt `Hytale Language German v1.5.zip` direkt aus diesem GitHub-Repository herunter,
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
