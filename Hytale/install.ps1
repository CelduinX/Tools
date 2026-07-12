$ErrorActionPreference = 'Stop'

$zipUrl = 'https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/Hytale%20Language%20German%20v1.5.zip'
$expectedHash = '57E59AE6A1F9AB34A4F9047EC25D0FDD03807F82EC2C1B6393A1E826BA490753'
$tempBase = Join-Path ([IO.Path]::GetTempPath()) ('hytale-de-' + [guid]::NewGuid())
$zipFile = "$tempBase.zip"

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    $actualHash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw 'Die heruntergeladene ZIP-Datei ist beschädigt oder wurde verändert.'
    }

    Expand-Archive -LiteralPath $zipFile -DestinationPath $tempBase -Force
    $installFolders = @(Get-ChildItem -LiteralPath $tempBase -Directory -Recurse | Where-Object Name -eq 'install')
    if ($installFolders.Count -ne 1) {
        throw "Erwartet wurde genau ein install-Ordner, gefunden: $($installFolders.Count)"
    }

    $destination = Join-Path $env:APPDATA 'Hytale\install'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath $installFolders[0].FullName -Force |
        Copy-Item -Destination $destination -Recurse -Force

    Write-Host 'Hytale wurde erfolgreich auf Deutsch umgestellt.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $zipFile, $tempBase -Recurse -Force -ErrorAction SilentlyContinue
}
