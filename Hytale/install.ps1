$ErrorActionPreference = 'Stop'

$zipUrl = 'https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/Deutsches_Sprachpaket-2.0.1-komplett.zip'
$expectedHash = '95418AD6EDB2B218B2EF6C941DCFAB8C9D2879760A0FE1BA13C3F519032EFBAC'
$tempBase = Join-Path ([IO.Path]::GetTempPath()) ('hytale-de-' + [guid]::NewGuid())
$zipFile = "$tempBase.zip"

try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

    $actualHash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        throw 'Die heruntergeladene ZIP-Datei ist beschädigt oder wurde verändert.'
    }

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

    $modsDestination = Join-Path $env:APPDATA 'Hytale\UserData\Mods'
    $languageDestination = Join-Path $env:APPDATA 'Hytale\install\release\package\game\latest\Client\Data\Shared\Language\de-DE'
    New-Item -ItemType Directory -Path $modsDestination, $languageDestination -Force | Out-Null
    Copy-Item -LiteralPath $zipFile -Destination (Join-Path $modsDestination 'Deutsches_Sprachpaket.zip') -Force
    Get-ChildItem -LiteralPath (Join-Path $tempBase 'Menuesprache\de-DE') -Force |
        Copy-Item -Destination $languageDestination -Recurse -Force

    Write-Host 'Deutsches Sprachpaket 2.0.1 und Menuesprache wurden installiert.' -ForegroundColor Green
    Write-Host 'In Hytale unter Settings > Language die Sprache Deutsch auswaehlen. Die Mod muss fuer die Spielwelt aktiviert sein.'
}
finally {
    Remove-Item -LiteralPath $zipFile, $tempBase -Recurse -Force -ErrorAction SilentlyContinue
}
