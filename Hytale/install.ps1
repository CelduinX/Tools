$ErrorActionPreference = 'Stop'

function Install-HytaleLanguagePack {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $zipUrl = 'https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/Deutsches_Sprachpaket-2.0.1-komplett.zip'
    $expectedHash = '95418AD6EDB2B218B2EF6C941DCFAB8C9D2879760A0FE1BA13C3F519032EFBAC'
    $tempBase = Join-Path ([IO.Path]::GetTempPath()) ('hytale-de-' + [guid]::NewGuid())
    $zipFile = "$tempBase.zip"

    try {
        Write-Host '[1/4] Sprachpaket herunterladen ...' -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing -TimeoutSec 90
        }
        catch { throw "HYTALE_DOWNLOAD: $($_.Exception.Message)" }

        Write-Host '[2/4] Download prüfen ...' -ForegroundColor Cyan
        if ((Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'HYTALE_VERIFY: Die heruntergeladene Datei konnte nicht bestätigt werden.'
        }

        try {
            Expand-Archive -LiteralPath $zipFile -DestinationPath $tempBase -Force
            $requiredFiles = @(
                'manifest.json',
                'Server\Languages\de-DE\server.lang',
                'Server\Languages\de-DE\wordlists.lang',
                'Menuesprache\de-DE\meta.lang',
                'Menuesprache\de-DE\client.lang',
                'Common\Languages\de-DE\avatarCustomization\haircuts.lang',
                'Menuesprache\de-DE\avatarCustomization\haircuts.lang'
            )
            foreach ($relativePath in $requiredFiles) {
                if (-not (Test-Path -LiteralPath (Join-Path $tempBase $relativePath) -PathType Leaf)) {
                    throw "Im Sprachpaket fehlt die erforderliche Datei: $relativePath"
                }
            }
        }
        catch { throw "HYTALE_ARCHIVE: $($_.Exception.Message)" }

        try {
            Write-Host '[3/4] Sprachpaket installieren ...' -ForegroundColor Cyan
            $modsDestination = Join-Path $env:APPDATA 'Hytale\UserData\Mods'
            $languageDestination = Join-Path $env:APPDATA 'Hytale\install\release\package\game\latest\Client\Data\Shared\Language\de-DE'
            New-Item -ItemType Directory -Path $modsDestination, $languageDestination -Force | Out-Null
            Copy-Item -LiteralPath $zipFile -Destination (Join-Path $modsDestination 'Deutsches_Sprachpaket.zip') -Force

            Write-Host '[4/4] Menüsprache einrichten ...' -ForegroundColor Cyan
            Get-ChildItem -LiteralPath (Join-Path $tempBase 'Menuesprache\de-DE') -Force |
                Copy-Item -Destination $languageDestination -Recurse -Force
        }
        catch { throw "HYTALE_WRITE: $($_.Exception.Message)" }
    }
    finally {
        # Both paths are created exclusively for this attempt, never installation paths.
        Remove-Item -LiteralPath $zipFile, $tempBase -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-HytaleFailureMessage {
    param([string]$Detail)

    switch -Wildcard ($Detail) {
        '*HYTALE_DOWNLOAD*' { return 'Das Sprachpaket konnte nicht heruntergeladen werden. Prüfe deine Internetverbindung und versuche es erneut.' }
        '*HYTALE_VERIFY*' { return 'Der Download konnte nicht sicher geprüft werden. Es wurde nichts installiert. Bitte versuche es erneut.' }
        '*HYTALE_ARCHIVE*' { return 'Das Sprachpaket ist unvollständig oder konnte nicht geöffnet werden. Es wurde nichts installiert. Bitte versuche es erneut.' }
        '*HYTALE_WRITE*' { return 'Die Installation konnte nicht abgeschlossen werden. Schließe Hytale und prüfe, ob genügend Speicherplatz frei ist. Ein Teil kann bereits installiert sein; versuche es danach erneut.' }
        default { return 'Die Installation konnte nicht abgeschlossen werden. Bitte versuche es erneut.' }
    }
}

Write-Host ''
Write-Host '  HYTALE AUF DEUTSCH' -ForegroundColor Cyan
Write-Host '  Dein Abenteuer. Deine Sprache.'
Write-Host '  Hytale 0.7 | Sprachpaket 2.0.1'
Write-Host ''

try {
    Install-HytaleLanguagePack
    Write-Host ''
    Write-Host 'Fertig! Dein Sprachpaket ist installiert.' -ForegroundColor Green
    Write-Host ''
    Write-Host '1. Starte Hytale.'
    Write-Host '2. Wähle Settings > Language > Deutsch.'
    Write-Host '3. Aktiviere das Sprachpaket für deine Spielwelt.'
    Write-Host ''
    Write-Host 'Viel Spaß bei deinem nächsten Abenteuer!'
}
catch {
    throw (Get-HytaleFailureMessage $_.Exception.Message)
}
