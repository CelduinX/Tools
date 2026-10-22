#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt ein zeitgestempeltes Windows-Diagnosepaket auf dem Desktop.
.DESCRIPTION
    Sammelt Windows-Ereignisse der letzten 7 Tage, DxDiag, System- und Treiberinfos,
    Zuverlaessigkeitsverlauf sowie Windows-Fehlerberichte (nur Metadaten).
    Es werden keine Kennwoerter, Browserdaten oder persoenlichen Dateien eingelesen.
    Achtung: Windows-Ereignisse und Systemberichte koennen sensible Daten enthalten.
#>

$ErrorActionPreference = 'Stop'
$days = 7

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Bei lokal gespeicherter Skriptdatei UAC-Anfrage automatisch ausloesen.
if (-not (Test-IsAdministrator) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Write-Host 'Administratorrechte werden fuer vollstaendigere Ereignisprotokolle angefordert ...' -ForegroundColor Cyan
    try {
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
        return
    }
    catch {
        Write-Warning 'UAC wurde abgebrochen oder ist nicht verfuegbar. Es wird mit eingeschraenkten Rechten fortgefahren.'
    }
}

$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop -PathType Container)) {
    Write-Error 'Der Desktop-Ordner wurde nicht gefunden. Diagnose abgebrochen.'
    exit 1
}

$baseName = 'Systemdiagnose_{0}' -f $stamp
$zipPath = Join-Path $desktop ($baseName + '.zip')
$workDir = Join-Path ([IO.Path]::GetTempPath()) ($baseName + '_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$folderInfo = Join-Path $workDir 'Systeminformationen'
$folderEvents = Join-Path $workDir 'Ereignisprotokolle'
$folderCrashes = Join-Path $workDir 'Abstuerze'
$folderReports = Join-Path $workDir 'Berichte'
@($workDir, $folderInfo, $folderEvents, $folderCrashes, $folderReports) | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}
$log = New-Object 'System.Collections.Generic.List[string]'

function Write-Status {
    param([string]$Label, [string]$Message)
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Label, $Message
    $script:log.Add($line)
    if ($Label -eq 'WARNUNG') { Write-Warning $Message }
    else { Write-Host $line }
}

function Invoke-Collection {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action
        Write-Status 'OK' $Name
    }
    catch {
        Write-Status 'WARNUNG' ('{0}: {1}' -f $Name, $_.Exception.Message)
    }
}

function Save-Json {
    param([string]$Path, [object]$Object)
    $Object | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $Path -Encoding UTF8 -Force
}

function Invoke-ExternalReport {
    param([string]$Name, [string]$Executable, [string]$Args, [string]$OutputFile, [int]$TimeoutSeconds = 75)
    $process = Start-Process -FilePath $Executable -ArgumentList $Args -PassThru -ErrorAction Stop
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill() } catch { }
            throw ('Zeitlimit von {0}s ueberschritten' -f $TimeoutSeconds)
        }
        if (-not (Test-Path -LiteralPath $OutputFile)) {
            throw 'Die Ausgabedatei wurde nicht erstellt.'
        }
    }
    finally { $process.Dispose() }
}

Write-Host ''
Write-Host '=== Windows-Systemdiagnose ===' -ForegroundColor Cyan
Write-Status 'INFO' ('Zeitraum: letzte {0} Tage | Administrator: {1}' -f $days, (Test-IsAdministrator))
$since = (Get-Date).AddDays(-$days)
$msFromNow = [int64]([timespan]::FromDays($days).TotalMilliseconds)

$intro = @"
WINDOWS-SYSTEMDIAGNOSE
======================
Erstellt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
Computer: $env:COMPUTERNAME
Zeitraum: letzte $days Tage
Administratorrechte: $(Test-IsAdministrator)

Enthaltene Daten:
- Systeminfos: Windows, CPU, RAM, Datentraeger, GPU, Audio und Treiber
- Ereignisprotokolle: System / Anwendung, Fehler, Warnungen und Abstuerze
- DxDiag (Grafik- und Audio-Diagnose), MSInfo32 (falls verfuegbar)
- Zuverlaessigkeitsverlauf und WER-Berichtsuebersicht (falls verfuegbar)

WICHTIG: Enthaltene Logs koennen Benutzernamen, Computernamen, Programmpfade,
Fehlermeldungen und andere persoenliche Informationen enthalten.
Die ZIP daher nur an vertraute Personen senden, nicht oeffentlich hochladen.
"@
$intro | Out-File -LiteralPath (Join-Path $workDir 'LIESMICH.txt') -Encoding UTF8

Invoke-Collection 'Windows und Hardware' {
    $data = [ordered]@{
        Erstellt = (Get-Date).ToString('o')
        Windows = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime, TotalVisibleMemorySize, FreePhysicalMemory
        Computer = Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory
        Prozessor = @(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors)
        Grafik = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate, VideoModeDescription, AdapterRAM, Status)
        Audio = @(Get-CimInstance Win32_SoundDevice | Select-Object Name, Manufacturer, Status)
        Laufwerke = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID, VolumeName, Size, FreeSpace)
        BIOS = @(Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate)
    }
    Save-Json (Join-Path $folderInfo 'Hardware_und_Windows.json') $data
}

Invoke-Collection 'Grafik- und Audiotreiber' {
    $drivers = @(Get-CimInstance Win32_PnPSignedDriver | Where-Object {
        $_.DeviceClass -in @('DISPLAY','MEDIA')
    } | Select-Object DeviceName, DeviceClass, DriverProviderName, DriverVersion, DriverDate, InfName)
    $drivers | Export-Csv -LiteralPath (Join-Path $folderInfo 'Grafik_Audio_Treiber.csv') -NoTypeInformation -Encoding UTF8
}

Invoke-Collection 'DxDiag-Bericht' {
    $output = Join-Path $folderReports 'DxDiag.txt'
    Invoke-ExternalReport -Name 'DxDiag' -Executable 'dxdiag.exe' -Args ('/whql:off /t "{0}"' -f $output) -OutputFile $output -TimeoutSeconds 90
}

Invoke-Collection 'MSInfo32-Systembericht' {
    $output = Join-Path $folderReports 'MSInfo32.txt'
    Invoke-ExternalReport -Name 'MSInfo32' -Executable 'msinfo32.exe' -Args ('/report "{0}"' -f $output) -OutputFile $output -TimeoutSeconds 90
}

$eventLogs = @(
    @{ Name = 'System'; File = 'System' },
    @{ Name = 'Application'; File = 'Application' },
    @{ Name = 'Microsoft-Windows-Diagnostics-Performance/Operational'; File = 'Start_Leistung' },
    @{ Name = 'Microsoft-Windows-Windows Error Reporting/Operational'; File = 'Windows_Fehlerberichte' }
)

foreach ($entry in $eventLogs) {
    $eventName = $entry.Name
    $fileName = $entry.File
    Invoke-Collection ('Ereignisprotokoll ' + $eventName) {
        $list = Get-WinEvent -ListLog $eventName -ErrorAction Stop
        if (-not $list.IsEnabled) { throw 'Protokoll ist deaktiviert.' }
        $evtx = Join-Path $folderEvents ($fileName + '_7Tage.evtx')
        $query = '*[System[TimeCreated[timediff(@SystemTime) <= {0}]]]' -f $msFromNow
        & wevtutil.exe epl $eventName $evtx ("/q:$query") '/ow:true' 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $evtx)) {
            throw ('EVTX-Export fehlgeschlagen (Exitcode {0}).' -f $LASTEXITCODE)
        }
    }
}

foreach ($eventName in @('System', 'Application')) {
    Invoke-Collection ('Fehleruebersicht ' + $eventName) {
        $events = @(Get-WinEvent -FilterHashtable @{
            LogName = $eventName
            StartTime = $since
            Level = @(1, 2, 3)
        } -MaxEvents 500 -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Zeitpunkt = $_.TimeCreated
                Stufe = $_.LevelDisplayName
                Quelle = $_.ProviderName
                EreignisID = $_.Id
                Nachricht = if ($_.Message) { $_.Message.Substring(0, [Math]::Min(1800, $_.Message.Length)) } else { '' }
            }
        })
        $events | Export-Csv -LiteralPath (Join-Path $folderEvents ($eventName + '_Fehleruebersicht.csv')) -NoTypeInformation -Encoding UTF8
    }
}

Invoke-Collection 'Zuverlaessigkeitsverlauf' {
    $records = @(Get-CimInstance Win32_ReliabilityRecords -ErrorAction Stop | Where-Object {
        $_.TimeGenerated -ge $since
    } | Select-Object TimeGenerated, SourceName, EventIdentifier, ProductName, Message)
    $records | Export-Csv -LiteralPath (Join-Path $folderCrashes 'Zuverlaessigkeitsverlauf.csv') -NoTypeInformation -Encoding UTF8
}

Invoke-Collection 'Windows-Fehlerbericht-Metadaten (WER)' {
    $werRoot = Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'
    $results = @()
    if (Test-Path -LiteralPath $werRoot) {
        $results = @(Get-ChildItem -LiteralPath $werRoot -Directory -ErrorAction Stop | Where-Object {
            $_.LastWriteTime -ge $since
        } | Select-Object Name, LastWriteTime)
    }
    $results | Export-Csv -LiteralPath (Join-Path $folderCrashes 'WER_Berichtsnamen.csv') -NoTypeInformation -Encoding UTF8
}

$log | Out-File -LiteralPath (Join-Path $workDir 'Sammlungsprotokoll.txt') -Encoding UTF8

try {
    Write-Host 'ZIP-Datei wird erstellt ...' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $zipPath) { throw 'Ziel-ZIP existiert bereits.' }
    Compress-Archive -Path (Join-Path $workDir '*') -DestinationPath $zipPath -CompressionLevel Optimal -ErrorAction Stop
    $sizeMB = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1MB, 1)
    Write-Host ''
    Write-Host ('FERTIG: {0} ({1} MB)' -f $zipPath, $sizeMB) -ForegroundColor Green
    Write-Host 'Datenschutz: Vor dem Weitergeben bitte die ZIP-Inhalte pruefen.' -ForegroundColor Yellow
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Error ('ZIP-Erstellung fehlgeschlagen: {0}. Gesammelte Daten verbleiben unter: {1}' -f $_.Exception.Message, $workDir)
    exit 1
}
