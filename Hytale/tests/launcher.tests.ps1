$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$readme = [IO.File]::ReadAllText((Join-Path $repoRoot 'Hytale/README.md'))
$rootReadme = [IO.File]::ReadAllText((Join-Path $repoRoot 'README.md'))
$command = @($readme -split '\r?\n' | Where-Object { $_.StartsWith('powershell.exe ') })
if ($command.Count -ne 1 -or -not $rootReadme.Contains($command[0])) { throw 'README commands differ' }
if ($command[0].Length -ge 260) { throw 'Run command is too long' }
if ($command[0] -match 'Hidden|ComObject|Windows.Forms|EncodedCommand') { throw 'Unexpected graphical or hidden launcher' }
$payload = [regex]::Match($command[0], ' -Command "(.*)"$').Groups[1].Value
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseInput($payload, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }

# Exercise the exact published payload with local fixtures, without downloading or installing.
function Invoke-RestMethod {
    param($Uri, [Alias('ea')]$ErrorAction)
    if ($ErrorAction -ne 'Stop') { throw 'Download must stop on error' }
    if ($script:failDownload) { throw 'TEST_NETWORK_FAILURE' }
    if ($script:useActualInstaller) {
        # Preserve every downloaded character; ReadAllText would hide a leading BOM.
        return [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'Hytale/install.ps1')))
    }
    return "Write-Host 'TEST_INSTALL_COMPLETED'"
}
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec)
    Copy-Item -LiteralPath (Join-Path $repoRoot 'Hytale/Deutsches_Sprachpaket-2.0.1-komplett.zip') -Destination $OutFile
}
function Write-Host {
    param($Object, $ForegroundColor)
    $script:messages += [string]$Object
}
function Read-Host {
    param($Prompt)
    $script:confirmations++
    if ($Prompt -ne 'Enter zum Schliessen') { throw 'Confirmation prompt changed' }
    if ($script:messages.Count -eq 0) { throw 'Prompt appeared before result' }
}
foreach ($failure in @($false, $true)) {
    $script:failDownload = $failure
    $script:messages = @()
    $script:confirmations = 0
    & ([scriptblock]::Create($payload))
    if ($script:confirmations -ne 1) { throw 'Missing final confirmation' }
    if ($failure) {
        if ($script:messages -notcontains 'TEST_NETWORK_FAILURE' -or $script:messages -contains 'TEST_INSTALL_COMPLETED') { throw 'Download failure was not displayed correctly' }
    }
    elseif ($script:messages -notcontains 'TEST_INSTALL_COMPLETED') { throw 'Installer did not run' }
}
Write-Output "PASS: matching README commands ($($command[0].Length) characters), PowerShell syntax, success and download failure both reach confirmation"

$originalAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path ([IO.Path]::GetTempPath()) ('hytale-launcher-test-' + [guid]::NewGuid())
    $script:useActualInstaller = $true
    $script:failDownload = $false
    $script:messages = @()
    $script:confirmations = 0
    $installerBytes = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'Hytale/install.ps1'))
    if ($installerBytes[0] -eq 0xEF -and $installerBytes[1] -eq 0xBB -and $installerBytes[2] -eq 0xBF) { throw 'Downloaded installer must not have a UTF-8 BOM' }
    & ([scriptblock]::Create($payload))
    if ($script:messages -notcontains 'Fertig! Dein Sprachpaket ist installiert.') { throw 'Actual downloaded installer did not complete' }
    if ($script:confirmations -ne 1) { throw 'Actual installer skipped confirmation' }
    $installedZip = Join-Path $env:APPDATA 'Hytale/UserData/Mods/Deutsches_Sprachpaket.zip'
    if (-not (Test-Path -LiteralPath $installedZip)) { throw 'Actual installer did not install the mod' }
    Write-Output 'PASS: exact installer bytes through download/IEX, complete installation and final confirmation'
}
finally { $env:APPDATA = $originalAppData }
