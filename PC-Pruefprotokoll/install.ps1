$ErrorActionPreference = 'Stop'

$rawScriptUrl = 'https://raw.githubusercontent.com/CelduinX/Tools/main/PC-Pruefprotokoll/PC-Pruefung.ps1'
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ('PC-Pruefprotokoll-{0}' -f [guid]::NewGuid().ToString('N'))
$temporaryScript = Join-Path $temporaryDirectory 'PC-Pruefung.ps1'
$previousSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol

try {
    New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = $previousSecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $rawScriptUrl -UseBasicParsing -OutFile $temporaryScript

    if (-not (Test-Path -LiteralPath $temporaryScript) -or (Get-Item -LiteralPath $temporaryScript).Length -lt 1000) {
        throw 'Das PC-Prüfskript wurde nicht vollständig heruntergeladen.'
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $temporaryScript
    if ($LASTEXITCODE -ne 0) {
        throw ('Die PC-Prüfung wurde mit Fehlercode {0} beendet.' -f $LASTEXITCODE)
    }
}
finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousSecurityProtocol
    if (Test-Path -LiteralPath $temporaryScript) {
        Remove-Item -LiteralPath $temporaryScript -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Force -ErrorAction SilentlyContinue
    }
}
