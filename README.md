# Tools

Eine Sammlung kleiner Hilfswerkzeuge und automatisierter Setups.

## Hytale auf Deutsch

Installiert die deutschen Sprachdateien automatisch unter Windows:

```powershell
$u='https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/Hytale%20Language%20German%20v1.5.zip';$z=Join-Path $env:TEMP ('hytale-de-'+[guid]::NewGuid()+'.zip');$x=Join-Path $env:TEMP ('hytale-de-'+[guid]::NewGuid());try{Invoke-WebRequest -Uri $u -OutFile $z -UseBasicParsing;Expand-Archive -LiteralPath $z -DestinationPath $x -Force;$s=@(Get-ChildItem -LiteralPath $x -Directory -Recurse | Where-Object Name -eq 'install');if($s.Count-ne 1){throw "Erwartet wurde genau ein install-Ordner, gefunden: $($s.Count)"};$d=Join-Path $env:APPDATA 'Hytale\install';New-Item -ItemType Directory -Path $d -Force|Out-Null;Get-ChildItem -LiteralPath $s[0].FullName -Force|Copy-Item -Destination $d -Recurse -Force;Write-Host 'Hytale wurde erfolgreich auf Deutsch umgestellt.' -ForegroundColor Green}finally{Remove-Item -LiteralPath $z,$x -Recurse -Force -ErrorAction SilentlyContinue}
```

Eine ausführliche Anleitung und Hinweise gibt es unter [Hytale](Hytale/README.md).

## Automatic Docker Setup

```bash
curl -fsSL https://raw.githubusercontent.com/CelduinX/Tools/refs/heads/main/Docker/setup-ubuntu-docker.sh | sudo DOCKER_BASE_DIR=/opt/docker bash
```
