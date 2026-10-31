$ErrorActionPreference = 'Stop'
$hytaleRoot = Split-Path $PSScriptRoot -Parent
$tokens = $null
$parseErrors = $null
$installerText = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $hytaleRoot 'install.ps1')))
$ast = [Management.Automation.Language.Parser]::ParseInput($installerText, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Install-HytaleLanguagePack', 'Get-HytaleFailureMessage') }, $false))
foreach ($definition in $definitions) { . ([scriptblock]::Create($definition.Extent.Text)) }
$originalAppData = $env:APPDATA
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('hytale-installer-test-' + [guid]::NewGuid())
$sourceZip = Join-Path $hytaleRoot 'Deutsches_Sprachpaket-2.0.1-komplett.zip'
$expectedHash = (Get-FileHash -LiteralPath $sourceZip).Hash
New-Item -ItemType Directory -Path $testRoot | Out-Null

function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec)
    $script:lastDownload = $OutFile
    if ($script:downloadFailure) { throw 'Simulated connection failure' }
    Copy-Item -LiteralPath $script:fixture -Destination $OutFile
}
function Assert-Cleanup {
    Assert (-not (Test-Path -LiteralPath $script:lastDownload)) 'Temporary ZIP was not removed'
    Assert (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($script:lastDownload, $null)))) 'Temporary extraction was not removed'
}
function Assert-Failure([scriptblock]$Action, [string]$Category) {
    $message = ''
    try { & $Action } catch { $message = $_.Exception.Message }
    Assert ($message -like "*$Category*") "Expected $Category, got: $message"
    Assert-Cleanup
    return $message
}

try {
    $script:fixture = $sourceZip
    $script:downloadFailure = $false
    $env:APPDATA = Join-Path $testRoot 'success'
    $mods = Join-Path $env:APPDATA 'Hytale/UserData/Mods'
    New-Item -ItemType Directory -Path $mods -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $mods 'other-mod.zip'), 'unchanged')
    Install-HytaleLanguagePack
    Assert-Cleanup
    Assert ((Get-FileHash -LiteralPath (Join-Path $mods 'Deutsches_Sprachpaket.zip')).Hash -eq $expectedHash) 'Mod ZIP differs from original'
    $language = Join-Path $env:APPDATA 'Hytale/install/release/package/game/latest/Client/Data/Shared/Language/de-DE'
    $baseline = Join-Path $testRoot 'baseline'
    Expand-Archive -LiteralPath $sourceZip -DestinationPath $baseline
    $sourceLanguage = Join-Path $baseline 'Menuesprache/de-DE'
    $files = @(Get-ChildItem -LiteralPath $sourceLanguage -File -Recurse)
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($sourceLanguage.Length).TrimStart('\')
        Assert ((Get-FileHash -LiteralPath (Join-Path $language $relative)).Hash -eq (Get-FileHash -LiteralPath $file.FullName).Hash) "Language file differs: $relative"
    }
    [IO.File]::WriteAllText((Join-Path $language 'client.lang'), 'stale')
    [IO.File]::WriteAllText((Join-Path $language 'custom.lang'), 'unchanged')
    Install-HytaleLanguagePack
    Assert-Cleanup
    Assert ((Get-FileHash -LiteralPath (Join-Path $language 'client.lang')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $sourceLanguage 'client.lang')).Hash) 'Reinstallation did not restore client.lang'
    Assert ([IO.File]::ReadAllText((Join-Path $mods 'other-mod.zip')) -eq 'unchanged') 'Other mod changed'
    Assert ([IO.File]::ReadAllText((Join-Path $language 'custom.lang')) -eq 'unchanged') 'Custom language changed'
    Write-Output "PASS: installation, all $($files.Count) language files, reinstallation, unrelated files"

    $lock = [IO.File]::Open((Join-Path $language 'client.lang'), 'Open', 'ReadWrite', 'None')
    try { $detail = Assert-Failure { Install-HytaleLanguagePack } 'HYTALE_WRITE' }
    finally { $lock.Dispose() }
    Assert ((Get-HytaleFailureMessage $detail) -like '*Ein Teil*') 'Write failure hides partial installation'
    Install-HytaleLanguagePack
    Assert-Cleanup
    Write-Output 'PASS: locked destination reports failure and retry succeeds'

    $env:APPDATA = Join-Path $testRoot 'download-failure'
    $script:downloadFailure = $true
    $detail = Assert-Failure { Install-HytaleLanguagePack } 'HYTALE_DOWNLOAD'
    Assert (-not (Test-Path -LiteralPath $env:APPDATA)) 'Failed download changed installation'
    Assert ((Get-HytaleFailureMessage $detail) -like '*Internetverbindung*') 'Download help missing'
    $script:downloadFailure = $false
    Write-Output 'PASS: download failure, friendly message, no installation changes'

    $script:fixture = Join-Path $testRoot 'bad-hash.zip'
    [IO.File]::WriteAllText($script:fixture, 'corrupt')
    $env:APPDATA = Join-Path $testRoot 'hash-failure'
    $null = Assert-Failure { Install-HytaleLanguagePack } 'HYTALE_VERIFY'
    Assert (-not (Test-Path -LiteralPath $env:APPDATA)) 'Bad hash changed installation'
    Write-Output 'PASS: checksum rejection before installation'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $script:fixture = Join-Path $testRoot 'missing-file.zip'
    Copy-Item -LiteralPath $sourceZip -Destination $script:fixture
    $zip = [IO.Compression.ZipFile]::Open($script:fixture, 'Update')
    $zip.GetEntry('Menuesprache/de-DE/client.lang').Delete()
    $zip.Dispose()
    $testDefinition = $definitions | Where-Object Name -eq 'Install-HytaleLanguagePack'
    . ([scriptblock]::Create($testDefinition.Extent.Text.Replace($expectedHash, (Get-FileHash -LiteralPath $script:fixture).Hash)))
    $env:APPDATA = Join-Path $testRoot 'missing-file-failure'
    $null = Assert-Failure { Install-HytaleLanguagePack } 'HYTALE_ARCHIVE'
    Assert (-not (Test-Path -LiteralPath $env:APPDATA)) 'Missing file changed installation'
    Write-Output 'PASS: missing archive content rejected before installation'

}
finally {
    $env:APPDATA = $originalAppData
    Write-Output "Test artifacts: $testRoot"
}
