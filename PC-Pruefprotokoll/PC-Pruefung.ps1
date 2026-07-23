[CmdletBinding()]
param(
    [switch]$SkipElevation,
    [switch]$NoOpen,
    [string]$OutputRoot,
    [string[]]$Activities = @(),
    [switch]$NoActivityPrompt,
    [string]$ActivitiesEncoded
)

#requires -version 5.1

# Portables Diagnosewerkzeug für Windows 10 und Windows 11.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Checks = New-Object 'System.Collections.Generic.List[object]'
$script:CollectionErrors = New-Object 'System.Collections.Generic.List[object]'
$script:StartedAt = Get-Date

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedCopy {
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        ('"{0}"' -f $PSCommandPath)
    )

    if ($NoOpen) {
        $arguments += '-NoOpen'
    }
    if ($OutputRoot) {
        $arguments += '-OutputRoot'
        $arguments += ('"{0}"' -f $OutputRoot)
    }
    if ($NoActivityPrompt) {
        $arguments += '-NoActivityPrompt'
    }
    if ($Activities.Count -gt 0) {
        $activitiesJson = $Activities | ConvertTo-Json -Compress
        $activitiesBytes = [Text.Encoding]::UTF8.GetBytes($activitiesJson)
        $arguments += '-ActivitiesEncoded'
        $arguments += [Convert]::ToBase64String($activitiesBytes)
    }

    Write-Host 'Administratorrechte werden angefordert ...' -ForegroundColor Yellow
    try {
        $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments -Wait -PassThru
        exit $process.ExitCode
    }
    catch {
        Write-Host 'Die Administratorabfrage wurde abgebrochen oder konnte nicht gestartet werden.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        exit 1
    }
}

function Write-Step {
    param(
        [int]$Number,
        [int]$Total,
        [string]$Text
    )
    Write-Progress -Activity 'PC-Prüfung' -Status $Text -PercentComplete (($Number / $Total) * 100)
    Write-Host ('[{0}/{1}] {2}' -f $Number, $Total, $Text) -ForegroundColor Cyan
}

function Add-CollectionError {
    param(
        [string]$Area,
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    $script:CollectionErrors.Add([pscustomobject]@{
        Bereich = $Area
        Meldung = $ErrorRecord.Exception.Message
        Zeitpunkt = (Get-Date).ToString('o')
    })
}

function Add-Check {
    param(
        [string]$Category,
        [string]$Name,
        [ValidateSet('Bestanden', 'Warnung', 'Fehler', 'Nicht verfügbar')]
        [string]$Status,
        [string]$Summary,
        $Details = $null
    )
    $script:Checks.Add([pscustomobject]@{
        Kategorie = $Category
        Pruefung = $Name
        Status = $Status
        Zusammenfassung = $Summary
        Details = $Details
    })
}

function Convert-Bytes {
    param([Nullable[double]]$Bytes)
    if ($null -eq $Bytes) { return 'Nicht verfügbar' }
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return ('{0:N0} Byte' -f $Bytes)
}

function Convert-WmiDate {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return $Value }
    try { return [Management.ManagementDateTimeConverter]::ToDateTime([string]$Value) }
    catch { return $null }
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name,
        $Default = $null
    )
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Get-WindowsVersionDetails {
    param($OperatingSystem)

    $currentVersion = $null
    try {
        $currentVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    }
    catch { }

    $caption = [string](Get-PropertyValue $OperatingSystem 'Caption' '')
    $registryProductName = [string](Get-PropertyValue $currentVersion 'ProductName' '')
    $buildText = [string](Get-PropertyValue $currentVersion 'CurrentBuild' (Get-PropertyValue $OperatingSystem 'BuildNumber' ''))
    $buildNumber = 0
    [void][int]::TryParse($buildText, [ref]$buildNumber)
    $installationType = [string](Get-PropertyValue $currentVersion 'InstallationType' '')

    $windowsName = if (-not [string]::IsNullOrWhiteSpace($caption)) { $caption.Trim() } else { $registryProductName.Trim() }
    $isClient = [string]::IsNullOrWhiteSpace($installationType) -or $installationType -eq 'Client'
    if ($isClient -and $buildNumber -ge 22000) {
        if ([string]::IsNullOrWhiteSpace($windowsName)) {
            $windowsName = 'Microsoft Windows 11'
        }
        elseif ($windowsName -match 'Windows 10') {
            $windowsName = $windowsName -replace 'Windows 10', 'Windows 11'
        }
    }
    elseif ($isClient -and $buildNumber -ge 10240 -and [string]::IsNullOrWhiteSpace($windowsName)) {
        $windowsName = 'Microsoft Windows 10'
    }
    if ([string]::IsNullOrWhiteSpace($windowsName)) {
        $windowsName = 'Nicht verfügbar'
    }

    $displayVersion = [string](Get-PropertyValue $currentVersion 'DisplayVersion' (Get-PropertyValue $currentVersion 'ReleaseId' ''))
    if ([string]::IsNullOrWhiteSpace($displayVersion)) {
        $displayVersion = 'Nicht verfügbar'
    }

    $ubr = Get-PropertyValue $currentVersion 'UBR'
    $fullBuild = if (-not [string]::IsNullOrWhiteSpace($buildText)) {
        if ($null -ne $ubr -and ([string]$ubr) -match '^\d+$') { '{0}.{1}' -f $buildText, $ubr } else { $buildText }
    }
    else {
        'Nicht verfügbar'
    }

    return [pscustomobject]@{
        Windows = $windowsName
        FeatureVersion = $displayVersion
        Systemversion = (Get-PropertyValue $OperatingSystem 'Version' 'Nicht verfügbar')
        Build = $fullBuild
    }
}

function Get-TemperatureRating {
    param(
        [double]$Temperature,
        [ValidateSet('Prozessor', 'Grafik', 'Datenträger', 'System')]
        [string]$Type = 'System'
    )

    $warningLimit = switch ($Type) {
        'Datenträger' { 55 }
        'System' { 80 }
        default { 85 }
    }
    $errorLimit = switch ($Type) {
        'Datenträger' { 65 }
        'System' { 90 }
        default { 95 }
    }

    if ($Temperature -ge $errorLimit) { return 'Fehler' }
    if ($Temperature -ge $warningLimit) { return 'Warnung' }
    return 'Bestanden'
}

function Get-ValidTemperature {
    param($Value)
    if ($null -eq $Value) { return $null }
    try {
        $temperature = [double]$Value
        if ($temperature -gt 0 -and $temperature -le 150) {
            return [math]::Round($temperature, 1)
        }
    }
    catch { }
    return $null
}

function Get-SafeFileName {
    param([string]$Value)
    $invalid = [IO.Path]::GetInvalidFileNameChars()
    $result = $Value
    foreach ($character in $invalid) {
        $result = $result.Replace([string]$character, '_')
    }
    return $result
}

function Get-DocumentedActivities {
    $items = New-Object 'System.Collections.Generic.List[string]'

    if (-not [string]::IsNullOrWhiteSpace($ActivitiesEncoded)) {
        try {
            $decodedBytes = [Convert]::FromBase64String($ActivitiesEncoded)
            $decodedJson = [Text.Encoding]::UTF8.GetString($decodedBytes)
            $decodedActivities = $decodedJson | ConvertFrom-Json
            foreach ($activity in $decodedActivities) {
                if (-not [string]::IsNullOrWhiteSpace([string]$activity)) {
                    $items.Add(([string]$activity).Trim())
                }
            }
        }
        catch {
            Write-Host 'Übergebene Tätigkeiten konnten nicht gelesen werden und werden ignoriert.' -ForegroundColor Yellow
        }
    }
    else {
        foreach ($activity in $Activities) {
            if (-not [string]::IsNullOrWhiteSpace($activity)) {
                $items.Add($activity.Trim())
            }
        }
    }

    if (-not $NoActivityPrompt) {
        Write-Host ''
        Write-Host 'DURCHGEFÜHRTE TÄTIGKEITEN' -ForegroundColor White
        Write-Host 'Jede Tätigkeit einzeln eingeben. Eine leere Eingabe startet anschließend die Prüfung.' -ForegroundColor Gray
        while ($items.Count -lt 50) {
            $entry = Read-Host ('Tätigkeit {0}' -f ($items.Count + 1))
            if ([string]::IsNullOrWhiteSpace($entry)) { break }
            $items.Add($entry.Trim())
        }
        if ($items.Count -ge 50) {
            Write-Host 'Es wurden maximal 50 Tätigkeiten übernommen.' -ForegroundColor Yellow
        }
    }

    return $items.ToArray()
}

function Encode-Html {
    param($Value)
    if ($null -eq $Value) { return '' }
    return [Net.WebUtility]::HtmlEncode([string]$Value)
}

function Convert-DisplayValue {
    param($Value)
    if ($null -eq $Value) { return '—' }
    if ($Value -is [datetime]) { return $Value.ToString('dd.MM.yyyy HH:mm:ss') }
    if ($Value -is [bool]) { if ($Value) { return 'Ja' } else { return 'Nein' } }
    if ($Value -is [System.Collections.IDictionary]) {
        return ($Value | ConvertTo-Json -Compress -Depth 5)
    }
    if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
        $items = @($Value | ForEach-Object { Convert-DisplayValue $_ })
        return ($items -join '; ')
    }
    return [string]$Value
}

function Convert-DetailsToHtml {
    param($Details)
    if ($null -eq $Details) { return '' }

    $rows = @()
    if ($Details -is [System.Collections.IDictionary]) {
        $builder = New-Object Text.StringBuilder
        [void]$builder.Append('<div class="table-wrap"><table class="key-value"><thead><tr><th>Eigenschaft</th><th>Wert</th></tr></thead><tbody>')
        foreach ($key in $Details.Keys) {
            [void]$builder.Append(('<tr><td>{0}</td><td>{1}</td></tr>' -f
                (Encode-Html $key),
                (Encode-Html (Convert-DisplayValue $Details[$key]))))
        }
        [void]$builder.Append('</tbody></table></div>')
        return $builder.ToString()
    }
    elseif (($Details -is [System.Collections.IEnumerable]) -and -not ($Details -is [string])) {
        foreach ($entry in $Details) {
            if ($entry -is [System.Collections.IDictionary]) {
                $item = [ordered]@{}
                foreach ($key in $entry.Keys) { $item[[string]$key] = $entry[$key] }
                $rows += [pscustomobject]$item
            }
            else {
                $rows += $entry
            }
        }
    }
    else {
        $rows = @([pscustomobject]@{ Wert = $Details })
    }

    if ($rows.Count -eq 0) { return '' }

    $columns = New-Object 'System.Collections.Generic.List[string]'
    foreach ($row in $rows) {
        foreach ($property in $row.PSObject.Properties) {
            if (-not $columns.Contains($property.Name)) { $columns.Add($property.Name) }
        }
    }

    $builder = New-Object Text.StringBuilder
    $tableClass = if ($columns.Count -ge 7) { ' class="wide-table"' } else { '' }
    [void]$builder.Append(('<div class="table-wrap"><table{0}><thead><tr>' -f $tableClass))
    foreach ($column in $columns) {
        [void]$builder.Append(('<th>{0}</th>' -f (Encode-Html $column)))
    }
    [void]$builder.Append('</tr></thead><tbody>')
    foreach ($row in $rows) {
        [void]$builder.Append('<tr>')
        foreach ($column in $columns) {
            $property = $row.PSObject.Properties[$column]
            $value = if ($null -eq $property) { $null } else { $property.Value }
            [void]$builder.Append(('<td data-label="{0}">{1}</td>' -f
                (Encode-Html $column),
                (Encode-Html (Convert-DisplayValue $value))))
        }
        [void]$builder.Append('</tr>')
    }
    [void]$builder.Append('</tbody></table></div>')
    return $builder.ToString()
}

function Get-StatusClass {
    param([string]$Status)
    switch ($Status) {
        'Bestanden' { return 'passed' }
        'Warnung' { return 'warning' }
        'Fehler' { return 'failed' }
        default { return 'unavailable' }
    }
}

if (-not (Test-IsAdministrator) -and -not $SkipElevation) {
    Start-ElevatedCopy
}

$totalSteps = 10
$step = 0
$computerName = $env:COMPUTERNAME
$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [Environment]::GetFolderPath('Desktop')
}
$folderName = 'PC-Pruefprotokoll_{0}_{1}' -f (Get-SafeFileName $computerName), $timestamp
$outputDirectory = Join-Path $OutputRoot $folderName
$jsonPath = Join-Path $outputDirectory 'Pruefdaten.json'
$htmlPath = Join-Path $outputDirectory 'PC-Pruefprotokoll.html'

Write-Host ''
Write-Host 'PC-PRÜFPROTOKOLL' -ForegroundColor White
Write-Host ('Computer: {0}' -f $computerName)
$documentedActivities = @(Get-DocumentedActivities)
$script:StartedAt = Get-Date
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Write-Host ('Ausgabe:  {0}' -f $outputDirectory)
Write-Host ''

# 1. Systemidentifikation
$step++
Write-Step $step $totalSteps 'System und Windows erfassen'
try {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $installDate = Convert-WmiDate (Get-PropertyValue $os 'InstallDate')
    $lastBoot = Convert-WmiDate (Get-PropertyValue $os 'LastBootUpTime')
    $windowsVersion = Get-WindowsVersionDetails $os
    $systemDetails = [ordered]@{
        Computername = $computerName
        Hersteller = (Get-PropertyValue $computer 'Manufacturer' 'Nicht verfügbar')
        Modell = (Get-PropertyValue $computer 'Model' 'Nicht verfügbar')
        Seriennummer = (Get-PropertyValue $bios 'SerialNumber' 'Nicht verfügbar')
        Windows = $windowsVersion.Windows
        Windows_Version = $windowsVersion.FeatureVersion
        Build = $windowsVersion.Build
        Systemversion = $windowsVersion.Systemversion
        Architektur = (Get-PropertyValue $os 'OSArchitecture' 'Nicht verfügbar')
        Installiert_am = $installDate
        Letzter_Systemstart = $lastBoot
        BIOS_Version = (@(Get-PropertyValue $bios 'BIOSVersion' @()) -join ', ')
        BIOS_Datum = (Convert-WmiDate (Get-PropertyValue $bios 'ReleaseDate'))
    }
    Add-Check 'System' 'Systemidentifikation' 'Bestanden' 'Gerät und Windows wurden erfolgreich identifiziert.' $systemDetails
}
catch {
    Add-CollectionError 'Systemidentifikation' $_
    Add-Check 'System' 'Systemidentifikation' 'Nicht verfügbar' 'Systeminformationen konnten nicht vollständig gelesen werden.'
}

try {
    $license = Get-CimInstance -ClassName SoftwareLicensingProduct |
        Where-Object { $_.ApplicationID -eq '55c92734-d682-4d71-983e-d6ec3f16059f' -and $_.PartialProductKey } |
        Sort-Object LicenseStatus -Descending |
        Select-Object -First 1
    if ($null -eq $license) {
        Add-Check 'Windows' 'Windows-Aktivierung' 'Nicht verfügbar' 'Der Aktivierungszustand konnte nicht eindeutig ermittelt werden.'
    }
    elseif ([int]$license.LicenseStatus -eq 1) {
        Add-Check 'Windows' 'Windows-Aktivierung' 'Bestanden' 'Windows ist aktiviert.' ([ordered]@{
            Edition = $license.Name
            Beschreibung = $license.Description
        })
    }
    else {
        Add-Check 'Windows' 'Windows-Aktivierung' 'Fehler' 'Windows meldet keinen aktivierten Lizenzzustand.' ([ordered]@{
            Edition = $license.Name
            Lizenzstatus_Code = $license.LicenseStatus
        })
    }
}
catch {
    Add-CollectionError 'Windows-Aktivierung' $_
    Add-Check 'Windows' 'Windows-Aktivierung' 'Nicht verfügbar' 'Der Aktivierungszustand konnte nicht gelesen werden.'
}

# 2. Firmware und Geräteschutz
$step++
Write-Step $step $totalSteps 'Firmware und Geräteschutz prüfen'
try {
    if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
        try {
            $secureBoot = Confirm-SecureBootUEFI
            if ($secureBoot) {
                Add-Check 'Geräteschutz' 'Secure Boot' 'Bestanden' 'Secure Boot ist aktiviert.'
            }
            else {
                Add-Check 'Geräteschutz' 'Secure Boot' 'Warnung' 'Secure Boot ist deaktiviert.'
            }
        }
        catch {
            Add-Check 'Geräteschutz' 'Secure Boot' 'Warnung' 'Secure Boot wird von Firmware oder Startmodus nicht unterstützt.'
        }
    }
    else {
        Add-Check 'Geräteschutz' 'Secure Boot' 'Nicht verfügbar' 'Die Secure-Boot-Abfrage ist auf diesem System nicht verfügbar.'
    }
}
catch {
    Add-CollectionError 'Secure Boot' $_
    Add-Check 'Geräteschutz' 'Secure Boot' 'Nicht verfügbar' 'Secure Boot konnte nicht geprüft werden.'
}

try {
    if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
        $tpm = Get-Tpm
        $tpmPresent = [bool](Get-PropertyValue $tpm 'TpmPresent' $false)
        $tpmReady = [bool](Get-PropertyValue $tpm 'TpmReady' $false)
        $tpmEnabled = Get-PropertyValue $tpm 'TpmEnabled'
        $tpmOwned = Get-PropertyValue $tpm 'TpmOwned'
        if ($tpmPresent -and $tpmReady) {
            Add-Check 'Geräteschutz' 'TPM' 'Bestanden' 'Das TPM ist vorhanden und betriebsbereit.' ([ordered]@{
                Vorhanden = $tpmPresent
                Bereit = $tpmReady
                Aktiviert = $tpmEnabled
                Eigentümerstatus = $tpmOwned
            })
        }
        elseif ($null -eq $tpm.PSObject.Properties['TpmPresent']) {
            Add-Check 'Geräteschutz' 'TPM' 'Nicht verfügbar' 'Der TPM-Zustand konnte ohne erhöhte Rechte nicht vollständig gelesen werden.'
        }
        else {
            Add-Check 'Geräteschutz' 'TPM' 'Warnung' 'Das TPM fehlt oder ist nicht betriebsbereit.' ([ordered]@{
                Vorhanden = $tpmPresent
                Bereit = $tpmReady
                Aktiviert = $tpmEnabled
            })
        }
    }
    else {
        Add-Check 'Geräteschutz' 'TPM' 'Nicht verfügbar' 'Die TPM-Abfrage ist nicht verfügbar.'
    }
}
catch {
    Add-CollectionError 'TPM' $_
    Add-Check 'Geräteschutz' 'TPM' 'Nicht verfügbar' 'Der TPM-Zustand konnte nicht gelesen werden.'
}

# 3. Prozessor und Arbeitsspeicher
$step++
Write-Step $step $totalSteps 'Prozessor und Arbeitsspeicher erfassen'
try {
    $processors = @(Get-CimInstance -ClassName Win32_Processor)
    $memoryModules = @(Get-CimInstance -ClassName Win32_PhysicalMemory)
    $processorDetails = @($processors | ForEach-Object {
        [pscustomobject]@{
            Bezeichnung = $_.Name.Trim()
            Kerne = $_.NumberOfCores
            Logische_Prozessoren = $_.NumberOfLogicalProcessors
            Maximaltakt_MHz = $_.MaxClockSpeed
            Status = $_.Status
        }
    })
    Add-Check 'Hardware' 'Prozessor' 'Bestanden' ('{0} Prozessor(en) wurden erkannt.' -f $processors.Count) $processorDetails

    $totalMemory = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum
    $memoryDetails = @($memoryModules | ForEach-Object {
        [pscustomobject]@{
            Hersteller = $_.Manufacturer
            Teilenummer = ([string]$_.PartNumber).Trim()
            Kapazität = (Convert-Bytes ([double]$_.Capacity))
            Takt_MHz = $_.Speed
            Steckplatz = $_.DeviceLocator
        }
    })
    Add-Check 'Hardware' 'Arbeitsspeicher' 'Bestanden' ('{0} in {1} Modul(en) erkannt.' -f (Convert-Bytes $totalMemory), $memoryModules.Count) $memoryDetails
}
catch {
    Add-CollectionError 'Prozessor und Arbeitsspeicher' $_
    Add-Check 'Hardware' 'Prozessor und Arbeitsspeicher' 'Nicht verfügbar' 'CPU- oder Arbeitsspeicherdaten konnten nicht vollständig gelesen werden.'
}

try {
    $temperatureDetails = New-Object 'System.Collections.Generic.List[object]'
    $temperatureWeights = @{ 'Bestanden' = 1; 'Warnung' = 2; 'Fehler' = 3 }
    $temperatureStatus = 'Bestanden'

    try {
        $acpiSensors = @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop)
        foreach ($sensor in $acpiSensors) {
            $rawTemperature = [double](Get-PropertyValue $sensor 'CurrentTemperature' 0)
            $temperature = Get-ValidTemperature (($rawTemperature / 10) - 273.15)
            if ($null -eq $temperature) { continue }
            $rating = Get-TemperatureRating -Temperature $temperature -Type 'System'
            if ($temperatureWeights[$rating] -gt $temperatureWeights[$temperatureStatus]) {
                $temperatureStatus = $rating
            }
            $temperatureDetails.Add([pscustomobject]@{
                Sensor = (Get-PropertyValue $sensor 'InstanceName' 'ACPI-Thermalzone')
                Typ = 'System'
                Quelle = 'Windows ACPI'
                Temperatur_C = $temperature
                Bewertung = $rating
            })
        }
    }
    catch { }

    foreach ($provider in @(
        [pscustomobject]@{ Namespace = 'root/OpenHardwareMonitor'; Name = 'Open Hardware Monitor' },
        [pscustomobject]@{ Namespace = 'root/LibreHardwareMonitor'; Name = 'LibreHardwareMonitor' }
    )) {
        try {
            $providerSensors = @(Get-CimInstance -Namespace $provider.Namespace -ClassName Sensor -ErrorAction Stop |
                Where-Object { [string](Get-PropertyValue $_ 'SensorType' '') -eq 'Temperature' })
            foreach ($sensor in $providerSensors) {
                $temperature = Get-ValidTemperature (Get-PropertyValue $sensor 'Value')
                if ($null -eq $temperature) { continue }
                $sensorName = [string](Get-PropertyValue $sensor 'Name' 'Temperatursensor')
                $sensorIdentifier = [string](Get-PropertyValue $sensor 'Identifier' '')
                $sensorText = '{0} {1}' -f $sensorName, $sensorIdentifier
                $sensorType = if ($sensorText -match '(?i)cpu|processor|package|core') {
                    'Prozessor'
                }
                elseif ($sensorText -match '(?i)gpu|graphics') {
                    'Grafik'
                }
                elseif ($sensorText -match '(?i)drive|disk|ssd|hdd|nvme') {
                    'Datenträger'
                }
                else {
                    'System'
                }
                $rating = Get-TemperatureRating -Temperature $temperature -Type $sensorType
                if ($temperatureWeights[$rating] -gt $temperatureWeights[$temperatureStatus]) {
                    $temperatureStatus = $rating
                }
                $temperatureDetails.Add([pscustomobject]@{
                    Sensor = $sensorName
                    Typ = $sensorType
                    Quelle = $provider.Name
                    Temperatur_C = $temperature
                    Bewertung = $rating
                })
            }
        }
        catch { }
    }

    if ($temperatureDetails.Count -eq 0) {
        Add-Check 'Hardware' 'Temperaturen' 'Nicht verfügbar' 'Windows oder die installierten Hardwaretreiber stellen keine auslesbaren Temperatursensoren bereit.'
    }
    elseif ($temperatureStatus -eq 'Fehler') {
        Add-Check 'Hardware' 'Temperaturen' 'Fehler' 'Mindestens ein Temperatursensor meldet einen kritischen Wert.' $temperatureDetails.ToArray()
    }
    elseif ($temperatureStatus -eq 'Warnung') {
        Add-Check 'Hardware' 'Temperaturen' 'Warnung' 'Mindestens ein Temperatursensor meldet einen erhöhten Wert.' $temperatureDetails.ToArray()
    }
    else {
        Add-Check 'Hardware' 'Temperaturen' 'Bestanden' 'Alle verfügbaren Temperatursensoren melden unauffällige Werte.' $temperatureDetails.ToArray()
    }
}
catch {
    Add-CollectionError 'Temperaturen' $_
    Add-Check 'Hardware' 'Temperaturen' 'Nicht verfügbar' 'Temperaturwerte konnten nicht zuverlässig ausgewertet werden.'
}

# 4. Akku
$step++
Write-Step $step $totalSteps 'Akkuzustand prüfen'
try {
    $batteries = @(Get-CimInstance -ClassName Win32_Battery)
    if ($batteries.Count -eq 0) {
        Add-Check 'Hardware' 'Akku' 'Nicht verfügbar' 'Es wurde kein Akku erkannt; bei einem Desktop-PC ist dies normal.'
    }
    else {
        $batteryDetails = @()
        $lowestHealth = 100.0
        $healthAvailable = $false
        foreach ($battery in $batteries) {
            $design = [double](Get-PropertyValue $battery 'DesignCapacity' 0)
            $full = [double](Get-PropertyValue $battery 'FullChargeCapacity' 0)
            $health = $null
            if ($design -gt 0 -and $full -gt 0) {
                $health = [math]::Round(($full / $design) * 100, 1)
                $lowestHealth = [math]::Min($lowestHealth, $health)
                $healthAvailable = $true
            }
            $batteryDetails += [pscustomobject]@{
                Bezeichnung = $battery.Name
                Ladezustand_Prozent = $battery.EstimatedChargeRemaining
                Geschätzte_Gesundheit_Prozent = $health
                Designkapazität_mWh = $(if ($design -gt 0) { $design } else { $null })
                Vollladekapazität_mWh = $(if ($full -gt 0) { $full } else { $null })
                Status = $battery.Status
            }
        }
        if (-not $healthAvailable) {
            Add-Check 'Hardware' 'Akku' 'Nicht verfügbar' 'Ein Akku wurde erkannt, seine Verschleißdaten sind jedoch nicht verfügbar.' $batteryDetails
        }
        elseif ($lowestHealth -lt 40) {
            Add-Check 'Hardware' 'Akku' 'Fehler' ('Die geschätzte Akkugesundheit beträgt nur {0:N1} %.' -f $lowestHealth) $batteryDetails
        }
        elseif ($lowestHealth -lt 70) {
            Add-Check 'Hardware' 'Akku' 'Warnung' ('Die geschätzte Akkugesundheit beträgt {0:N1} %.' -f $lowestHealth) $batteryDetails
        }
        else {
            Add-Check 'Hardware' 'Akku' 'Bestanden' ('Die geschätzte Akkugesundheit beträgt mindestens {0:N1} %.' -f $lowestHealth) $batteryDetails
        }
    }
}
catch {
    Add-CollectionError 'Akku' $_
    Add-Check 'Hardware' 'Akku' 'Nicht verfügbar' 'Der Akkuzustand konnte nicht ausgelesen werden.'
}

# 5. Datenträger
$step++
Write-Step $step $totalSteps 'Datenträger und freien Speicher prüfen'
try {
    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $physicalDisks = @(Get-PhysicalDisk)
        if ($physicalDisks.Count -eq 0) {
            Add-Check 'Datenträger' 'Physische Datenträger' 'Nicht verfügbar' 'Windows hat keine physischen Datenträgerdaten bereitgestellt.'
        }
        else {
            $diskDetails = @()
            $diskTemperatureStatus = 'Bestanden'
            $diskTemperatureAvailable = $false
            foreach ($disk in $physicalDisks) {
                $reliability = $null
                try { $reliability = $disk | Get-StorageReliabilityCounter -ErrorAction Stop }
                catch { }
                $diskTemperature = Get-ValidTemperature (Get-PropertyValue $reliability 'Temperature')
                $diskTemperatureRating = if ($null -ne $diskTemperature) {
                    $diskTemperatureAvailable = $true
                    Get-TemperatureRating -Temperature $diskTemperature -Type 'Datenträger'
                }
                else {
                    'Nicht verfügbar'
                }
                if ($diskTemperatureRating -eq 'Fehler') {
                    $diskTemperatureStatus = 'Fehler'
                }
                elseif ($diskTemperatureRating -eq 'Warnung' -and $diskTemperatureStatus -ne 'Fehler') {
                    $diskTemperatureStatus = 'Warnung'
                }
                $diskDetail = [ordered]@{
                    Bezeichnung = $disk.FriendlyName
                    Seriennummer = ([string]$disk.SerialNumber).Trim()
                    Medientyp = $disk.MediaType
                    Bus = $disk.BusType
                    Kapazität = (Convert-Bytes ([double]$disk.Size))
                    Gesundheit = $disk.HealthStatus
                    Betriebsstatus = (@($disk.OperationalStatus) -join ', ')
                }
                if ($null -ne $diskTemperature) {
                    $diskDetail.Temperatur_C = $diskTemperature
                    $diskDetail.Temperaturstatus = $diskTemperatureRating
                }
                $powerOnHours = Get-PropertyValue $reliability 'PowerOnHours'
                $readErrors = Get-PropertyValue $reliability 'ReadErrorsTotal'
                $writeErrors = Get-PropertyValue $reliability 'WriteErrorsTotal'
                if ($null -ne $powerOnHours) { $diskDetail.Betriebsstunden = $powerOnHours }
                if ($null -ne $readErrors) { $diskDetail.Lesefehler = $readErrors }
                if ($null -ne $writeErrors) { $diskDetail.Schreibfehler = $writeErrors }
                $diskDetails += [pscustomobject]$diskDetail
            }
            $unhealthy = @($physicalDisks | Where-Object { [string]$_.HealthStatus -notin @('Healthy', 'Unknown') })
            if ($unhealthy.Count -gt 0) {
                Add-Check 'Datenträger' 'Physische Datenträger' 'Fehler' ('{0} Datenträger melden einen fehlerhaften Zustand.' -f $unhealthy.Count) $diskDetails
            }
            elseif ($diskTemperatureStatus -eq 'Fehler') {
                Add-Check 'Datenträger' 'Physische Datenträger' 'Fehler' 'Mindestens ein Datenträger meldet eine kritische Temperatur ab 65 °C.' $diskDetails
            }
            elseif ($diskTemperatureStatus -eq 'Warnung') {
                Add-Check 'Datenträger' 'Physische Datenträger' 'Warnung' 'Mindestens ein Datenträger meldet eine erhöhte Temperatur ab 55 °C.' $diskDetails
            }
            elseif (@($physicalDisks | Where-Object { [string]$_.HealthStatus -eq 'Unknown' }).Count -gt 0) {
                Add-Check 'Datenträger' 'Physische Datenträger' 'Nicht verfügbar' 'Mindestens ein Datenträger stellt keinen verlässlichen Gesundheitsstatus bereit.' $diskDetails
            }
            else {
                $diskSummary = if ($diskTemperatureAvailable) {
                    'Alle Datenträger melden einen unauffälligen Zustand und unkritische Temperaturen.'
                }
                else {
                    'Alle Datenträger melden einen unauffälligen Zustand; Temperaturwerte wurden nicht bereitgestellt.'
                }
                Add-Check 'Datenträger' 'Physische Datenträger' 'Bestanden' $diskSummary $diskDetails
            }
        }
    }
    else {
        Add-Check 'Datenträger' 'Physische Datenträger' 'Nicht verfügbar' 'Die Windows-Speicherverwaltung ist nicht verfügbar.'
    }
}
catch {
    Add-CollectionError 'Physische Datenträger' $_
    Add-Check 'Datenträger' 'Physische Datenträger' 'Nicht verfügbar' 'Datenträgerzustände konnten nicht gelesen werden.'
}

try {
    $volumes = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3')
    $volumeDetails = @()
    $lowVolumes = @()
    foreach ($volume in $volumes) {
        $percentFree = if ([double]$volume.Size -gt 0) {
            [math]::Round(([double]$volume.FreeSpace / [double]$volume.Size) * 100, 1)
        } else { 0 }
        if ($percentFree -lt 15) { $lowVolumes += $volume }
        $volumeDetails += [pscustomobject]@{
            Laufwerk = $volume.DeviceID
            Name = $volume.VolumeName
            Dateisystem = $volume.FileSystem
            Kapazität = (Convert-Bytes ([double]$volume.Size))
            Frei = (Convert-Bytes ([double]$volume.FreeSpace))
            Frei_Prozent = $percentFree
        }
    }
    if ($volumes.Count -eq 0) {
        Add-Check 'Datenträger' 'Freier Speicherplatz' 'Nicht verfügbar' 'Es wurden keine lokalen Volumes gefunden.'
    }
    elseif ($lowVolumes.Count -gt 0) {
        Add-Check 'Datenträger' 'Freier Speicherplatz' 'Warnung' ('{0} Volume(s) haben weniger als 15 % freien Speicher.' -f $lowVolumes.Count) $volumeDetails
    }
    else {
        Add-Check 'Datenträger' 'Freier Speicherplatz' 'Bestanden' 'Alle lokalen Volumes haben mindestens 15 % freien Speicher.' $volumeDetails
    }
}
catch {
    Add-CollectionError 'Freier Speicherplatz' $_
    Add-Check 'Datenträger' 'Freier Speicherplatz' 'Nicht verfügbar' 'Freier Speicherplatz konnte nicht ermittelt werden.'
}

# 6. Geräte und Treiber
$step++
Write-Step $step $totalSteps 'Geräte und Treiber prüfen'
try {
    $problemDevices = @(Get-CimInstance -ClassName Win32_PnPEntity |
        Where-Object { $null -ne $_.ConfigManagerErrorCode -and [int]$_.ConfigManagerErrorCode -ne 0 } |
        Sort-Object PNPClass, Name)
    if ($problemDevices.Count -eq 0) {
        Add-Check 'Geräte' 'Geräte-Manager' 'Bestanden' 'Windows meldet keine Geräte mit Fehlercode.'
    }
    else {
        $problemDetails = @($problemDevices | ForEach-Object {
            [pscustomobject]@{
                Gerät = $_.Name
                Klasse = $_.PNPClass
                Hersteller = $_.Manufacturer
                Fehlercode = $_.ConfigManagerErrorCode
                Geräte_ID = $_.DeviceID
            }
        })
        Add-Check 'Geräte' 'Geräte-Manager' 'Fehler' ('Windows meldet {0} Gerät(e) mit Fehlercode.' -f $problemDevices.Count) $problemDetails
    }
}
catch {
    Add-CollectionError 'Geräte-Manager' $_
    Add-Check 'Geräte' 'Geräte-Manager' 'Nicht verfügbar' 'Der Geräte-Manager-Status konnte nicht geprüft werden.'
}

# 7. Sicherheitssoftware und Firewall
$step++
Write-Step $step $totalSteps 'Virenschutz und Firewall prüfen'
try {
    $defender = $null
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        try { $defender = Get-MpComputerStatus } catch { }
    }
    $securityProducts = @()
    try {
        $securityProducts = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntivirusProduct)
    }
    catch { }

    $securityDetails = @()
    if ($null -ne $defender) {
        $securityDetails += [pscustomobject]@{
            Produkt = 'Microsoft Defender Antivirus'
            Aktiv = [bool]$defender.AntivirusEnabled
            Echtzeitschutz = [bool]$defender.RealTimeProtectionEnabled
            Signaturalter_Tage = $defender.AntivirusSignatureAge
            Signaturversion = $defender.AntivirusSignatureVersion
        }
    }
    foreach ($product in $securityProducts) {
        if ($product.displayName -ne 'Windows Defender') {
            $securityDetails += [pscustomobject]@{
                Produkt = $product.displayName
                Aktiv = 'Durch Windows-Sicherheitscenter registriert'
                Echtzeitschutz = 'Nicht separat geprüft'
                Signaturalter_Tage = $null
                Signaturversion = $null
            }
        }
    }

    $defenderActive = $null -ne $defender -and [bool]$defender.AntivirusEnabled -and [bool]$defender.RealTimeProtectionEnabled
    $thirdPartyRegistered = @($securityProducts | Where-Object { $_.displayName -ne 'Windows Defender' }).Count -gt 0
    if ($defenderActive) {
        if ([int]$defender.AntivirusSignatureAge -gt 3) {
            Add-Check 'Sicherheit' 'Virenschutz' 'Warnung' 'Microsoft Defender ist aktiv, seine Signaturen sind jedoch älter als drei Tage.' $securityDetails
        }
        else {
            Add-Check 'Sicherheit' 'Virenschutz' 'Bestanden' 'Microsoft Defender und der Echtzeitschutz sind aktiv.' $securityDetails
        }
    }
    elseif ($thirdPartyRegistered) {
        Add-Check 'Sicherheit' 'Virenschutz' 'Bestanden' 'Ein Virenschutzprodukt ist im Windows-Sicherheitscenter registriert.' $securityDetails
    }
    elseif ($null -eq $defender -and $securityProducts.Count -eq 0) {
        Add-Check 'Sicherheit' 'Virenschutz' 'Nicht verfügbar' 'Der Virenschutzstatus konnte nicht zuverlässig ermittelt werden.'
    }
    else {
        Add-Check 'Sicherheit' 'Virenschutz' 'Fehler' 'Es wurde kein aktiver Virenschutz erkannt.' $securityDetails
    }
}
catch {
    Add-CollectionError 'Virenschutz' $_
    Add-Check 'Sicherheit' 'Virenschutz' 'Nicht verfügbar' 'Der Virenschutzstatus konnte nicht geprüft werden.'
}

try {
    if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
        $firewallProfiles = @(Get-NetFirewallProfile)
        $firewallDetails = @($firewallProfiles | ForEach-Object {
            [pscustomobject]@{
                Profil = $_.Name
                Aktiviert = $_.Enabled
                Eingehend = $_.DefaultInboundAction
                Ausgehend = $_.DefaultOutboundAction
            }
        })
        $disabledProfiles = @($firewallProfiles | Where-Object { -not $_.Enabled })
        if ($disabledProfiles.Count -gt 0) {
            Add-Check 'Sicherheit' 'Windows-Firewall' 'Fehler' ('{0} Firewallprofil(e) sind deaktiviert.' -f $disabledProfiles.Count) $firewallDetails
        }
        else {
            Add-Check 'Sicherheit' 'Windows-Firewall' 'Bestanden' 'Alle Windows-Firewallprofile sind aktiviert.' $firewallDetails
        }
    }
    else {
        Add-Check 'Sicherheit' 'Windows-Firewall' 'Nicht verfügbar' 'Die Firewall-Abfrage ist nicht verfügbar.'
    }
}
catch {
    Add-CollectionError 'Windows-Firewall' $_
    Add-Check 'Sicherheit' 'Windows-Firewall' 'Nicht verfügbar' 'Der Firewallstatus konnte nicht geprüft werden.'
}

# 8. Windows Update
$step++
Write-Step $step $totalSteps 'Windows Update prüfen (kann einen Moment dauern)'
try {
    $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
    $pendingUpdates = @()
    for ($index = 0; $index -lt $searchResult.Updates.Count; $index++) {
        $update = $searchResult.Updates.Item($index)
        $pendingUpdates += [pscustomobject]@{
            Titel = $update.Title
            Wichtig = $update.IsMandatory
            Neustart_erforderlich = $update.RebootRequired
        }
    }
    if ($pendingUpdates.Count -gt 0) {
        Add-Check 'Windows Update' 'Ausstehende Updates' 'Warnung' ('Es stehen {0} Softwareupdate(s) aus.' -f $pendingUpdates.Count) $pendingUpdates
    }
    else {
        Add-Check 'Windows Update' 'Ausstehende Updates' 'Bestanden' 'Windows Update meldet keine ausstehenden Softwareupdates.'
    }
}
catch {
    Add-CollectionError 'Windows Update' $_
    Add-Check 'Windows Update' 'Ausstehende Updates' 'Nicht verfügbar' 'Die Windows-Update-Suche konnte nicht abgeschlossen werden.'
}

try {
    $rebootReasons = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $rebootReasons.Add('Komponentenwartung')
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $rebootReasons.Add('Windows Update')
    }
    $sessionManager = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction SilentlyContinue
    if ($null -ne $sessionManager -and $null -ne $sessionManager.PSObject.Properties['PendingFileRenameOperations']) {
        $rebootReasons.Add('Ausstehende Dateiumbenennung')
    }
    if ($rebootReasons.Count -gt 0) {
        Add-Check 'Windows Update' 'Ausstehender Neustart' 'Warnung' 'Windows benötigt einen Neustart.' ([ordered]@{
            Gründe = $rebootReasons.ToArray()
        })
    }
    else {
        Add-Check 'Windows Update' 'Ausstehender Neustart' 'Bestanden' 'Windows meldet keinen ausstehenden Neustart.'
    }
}
catch {
    Add-CollectionError 'Neustartstatus' $_
    Add-Check 'Windows Update' 'Ausstehender Neustart' 'Nicht verfügbar' 'Der Neustartstatus konnte nicht ermittelt werden.'
}

# 9. Netzwerk und Internet
$step++
Write-Step $step $totalSteps 'Netzwerk und Internetverbindung prüfen'
try {
    $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled })
    $networkDetails = @($adapters | ForEach-Object {
        [pscustomobject]@{
            Adapter = $_.Description
            MAC_Adresse = $_.MACAddress
            IP_Adressen = @($_.IPAddress)
            Subnetze = @($_.IPSubnet)
            Standardgateways = @($_.DefaultIPGateway)
            DNS_Server = @($_.DNSServerSearchOrder)
            DHCP = $_.DHCPEnabled
        }
    })
    if ($adapters.Count -eq 0) {
        Add-Check 'Netzwerk' 'Netzwerkkonfiguration' 'Warnung' 'Es wurde kein aktiver Netzwerkadapter mit IP-Konfiguration gefunden.'
    }
    elseif (@($adapters | Where-Object { @($_.DefaultIPGateway).Count -gt 0 }).Count -eq 0) {
        Add-Check 'Netzwerk' 'Netzwerkkonfiguration' 'Warnung' 'Eine IP-Konfiguration ist vorhanden, aber kein Standardgateway wurde erkannt.' $networkDetails
    }
    else {
        Add-Check 'Netzwerk' 'Netzwerkkonfiguration' 'Bestanden' ('{0} aktive Netzwerkverbindung(en) wurden erkannt.' -f $adapters.Count) $networkDetails
    }
}
catch {
    Add-CollectionError 'Netzwerkkonfiguration' $_
    Add-Check 'Netzwerk' 'Netzwerkkonfiguration' 'Nicht verfügbar' 'Die Netzwerkkonfiguration konnte nicht gelesen werden.'
}

try {
    $dnsResult = $null
    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
        $dnsResult = Resolve-DnsName -Name 'cloudflare.com' -Type A -ErrorAction Stop |
            Where-Object { $null -ne $_.PSObject.Properties['IPAddress'] -and -not [string]::IsNullOrWhiteSpace([string]$_.IPAddress) } |
            Select-Object -First 1
    }
    else {
        $dnsAddresses = [Net.Dns]::GetHostAddresses('cloudflare.com')
        $dnsResult = $dnsAddresses | Select-Object -First 1
    }
    if ($null -eq $dnsResult) {
        throw 'Die DNS-Abfrage lieferte keine IP-Adresse.'
    }
    Add-Check 'Netzwerk' 'DNS-Auflösung' 'Bestanden' 'Der Testname wurde über die Windows-DNS-Konfiguration erfolgreich aufgelöst.' ([ordered]@{
        Testziel = 'cloudflare.com'
        Ergebnis = $(if ($null -ne $dnsResult.PSObject.Properties['IPAddress']) { [string]$dnsResult.IPAddress } else { Convert-DisplayValue $dnsResult })
    })
}
catch {
    Add-CollectionError 'DNS-Auflösung' $_
    Add-Check 'Netzwerk' 'DNS-Auflösung' 'Fehler' 'Die DNS-Auflösung von cloudflare.com ist fehlgeschlagen.'
}

try {
    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
        $cloudflareAnswers = @(Resolve-DnsName -Name 'cloudflare.com' -Server '1.1.1.1' -Type A -DnsOnly -ErrorAction Stop |
            Where-Object { $null -ne $_.PSObject.Properties['IPAddress'] -and -not [string]::IsNullOrWhiteSpace([string]$_.IPAddress) })
        if ($cloudflareAnswers.Count -eq 0) {
            throw 'Der Cloudflare-DNS-Server lieferte keine IP-Adresse.'
        }
        $cloudflareDetails = [ordered]@{
            Server = '1.1.1.1 (Cloudflare DNS)'
            Testabfrage = 'cloudflare.com'
            Antworten = @($cloudflareAnswers | ForEach-Object { $_.IPAddress })
        }
    }
    else {
        $cloudflareTcp = New-Object Net.Sockets.TcpClient
        try {
            $connectResult = $cloudflareTcp.BeginConnect('1.1.1.1', 53, $null, $null)
            if (-not $connectResult.AsyncWaitHandle.WaitOne(5000)) {
                throw 'Zeitüberschreitung beim Verbindungsaufbau.'
            }
            $cloudflareTcp.EndConnect($connectResult)
        }
        finally {
            $cloudflareTcp.Close()
        }
        $cloudflareDetails = [ordered]@{
            Server = '1.1.1.1 (Cloudflare DNS)'
            Verbindung = 'TCP-Port 53'
        }
    }
    Add-Check 'Netzwerk' 'Internetverbindung' 'Bestanden' 'Der öffentliche Cloudflare-DNS-Server ist erreichbar und beantwortet die Testabfrage.' $cloudflareDetails
}
catch {
    Add-CollectionError 'Internetverbindung' $_
    Add-Check 'Netzwerk' 'Internetverbindung' 'Fehler' 'Der öffentliche Cloudflare-DNS-Server 1.1.1.1 konnte nicht erreicht oder abgefragt werden.'
}

# 10. Systemlaufzeit
$step++
Write-Step $step $totalSteps 'Systemlaufzeit ermitteln'
try {
    $osForBoot = Get-CimInstance -ClassName Win32_OperatingSystem
    $bootTime = Convert-WmiDate $osForBoot.LastBootUpTime
    $uptime = if ($null -ne $bootTime) { (Get-Date) - $bootTime } else { $null }
    Add-Check 'Stabilität' 'Systemlaufzeit' 'Bestanden' 'Der letzte Systemstart wurde ermittelt.' ([ordered]@{
        Letzter_Systemstart = $bootTime
        Laufzeit = $(if ($null -ne $uptime) { '{0} Tage, {1} Stunden, {2} Minuten' -f $uptime.Days, $uptime.Hours, $uptime.Minutes } else { 'Nicht verfügbar' })
    })
}
catch {
    Add-CollectionError 'Systemlaufzeit' $_
    Add-Check 'Stabilität' 'Systemlaufzeit' 'Nicht verfügbar' 'Der letzte Systemstart konnte nicht ermittelt werden.'
}

Write-Progress -Activity 'PC-Prüfung' -Completed

$statusWeights = @{
    'Nicht verfügbar' = 0
    'Bestanden' = 1
    'Warnung' = 2
    'Fehler' = 3
}
$overallStatus = 'Bestanden'
foreach ($check in $script:Checks) {
    if ($statusWeights[$check.Status] -gt $statusWeights[$overallStatus]) {
        $overallStatus = $check.Status
    }
}

$counts = [ordered]@{
    Bestanden = @($script:Checks | Where-Object Status -eq 'Bestanden').Count
    Warnung = @($script:Checks | Where-Object Status -eq 'Warnung').Count
    Fehler = @($script:Checks | Where-Object Status -eq 'Fehler').Count
    Nicht_verfügbar = @($script:Checks | Where-Object Status -eq 'Nicht verfügbar').Count
}

$finishedAt = Get-Date
$reportData = [ordered]@{
    SchemaVersion = '1.0'
    Bericht = 'PC-Prüfprotokoll'
    Computername = $computerName
    Erstellt = $finishedAt.ToString('o')
    Dauer_Sekunden = [math]::Round(($finishedAt - $script:StartedAt).TotalSeconds, 1)
    Als_Administrator = (Test-IsAdministrator)
    Gesamtstatus = $overallStatus
    Zusammenfassung = $counts
    Taetigkeiten = $documentedActivities
    Pruefungen = $script:Checks.ToArray()
    Erfassungsfehler = $script:CollectionErrors.ToArray()
    Hinweis = 'Technische Momentaufnahme zum Erstellungszeitpunkt; keine Garantie für zukünftige Fehlerfreiheit.'
}

$reportData | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$categoryOrder = @('System', 'Windows', 'Geräteschutz', 'Hardware', 'Datenträger', 'Geräte', 'Sicherheit', 'Windows Update', 'Netzwerk', 'Stabilität')
$cardsBuilder = New-Object Text.StringBuilder
foreach ($category in $categoryOrder) {
    $categoryChecks = @($script:Checks | Where-Object Kategorie -eq $category)
    if ($categoryChecks.Count -eq 0) { continue }
    [void]$cardsBuilder.Append(('<section class="report-section"><h2>{0}</h2>' -f (Encode-Html $category)))
    foreach ($check in $categoryChecks) {
        $class = Get-StatusClass $check.Status
        $detailsHtml = Convert-DetailsToHtml $check.Details
        [void]$cardsBuilder.Append(@"
<article class="check-card $class">
  <div class="check-heading">
    <h3>$(Encode-Html $check.Pruefung)</h3>
    <span class="status-badge $class">$(Encode-Html $check.Status)</span>
  </div>
  <p class="summary">$(Encode-Html $check.Zusammenfassung)</p>
  $detailsHtml
</article>
"@)
    }
    [void]$cardsBuilder.Append('</section>')
}

$overallClass = Get-StatusClass $overallStatus
$adminText = if (Test-IsAdministrator) { 'Ja' } else { 'Nein (eingeschränkte Abfragen möglich)' }
$durationText = '{0:N1} Sekunden' -f ($finishedAt - $script:StartedAt).TotalSeconds
$activitiesBuilder = New-Object Text.StringBuilder
if ($documentedActivities.Count -gt 0) {
    [void]$activitiesBuilder.Append('<ul class="activities-list">')
    foreach ($activity in $documentedActivities) {
        [void]$activitiesBuilder.Append(('<li>{0}</li>' -f (Encode-Html $activity)))
    }
    [void]$activitiesBuilder.Append('</ul>')
}
else {
    [void]$activitiesBuilder.Append('<p class="activities-empty">Keine zusätzlichen Tätigkeiten dokumentiert.</p>')
}
$html = @"
<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PC-Prüfprotokoll – $(Encode-Html $computerName)</title>
  <style>
    :root {
      --ink: #172033;
      --muted: #5f6b7a;
      --line: #dce2e9;
      --panel: #f6f8fa;
      --passed: #16794a;
      --passed-bg: #eaf7f0;
      --warning: #9a6200;
      --warning-bg: #fff5da;
      --failed: #b42318;
      --failed-bg: #ffebe9;
      --unavailable: #596579;
      --unavailable-bg: #eef1f5;
      --brand: #164b7a;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: #e9edf2;
      color: var(--ink);
      font-family: "Segoe UI", Arial, sans-serif;
      font-size: 14px;
      line-height: 1.45;
    }
    .page {
      max-width: 1120px;
      margin: 18px auto;
      background: white;
      box-shadow: 0 8px 28px rgba(19, 33, 50, .12);
    }
    .hero {
      padding: 22px 34px 16px;
      color: var(--ink);
      background: white;
      border-bottom: 3px solid var(--brand);
    }
    .eyebrow {
      margin: 0 0 4px;
      text-transform: uppercase;
      letter-spacing: .12em;
      color: var(--brand);
      font-size: 11px;
      font-weight: 650;
    }
    h1 { margin: 0; font-size: 28px; font-weight: 650; }
    .hero-subtitle { margin: 4px 0 0; color: var(--muted); }
    main { padding: 20px 34px 28px; }
    .overview {
      display: grid;
      grid-template-columns: 1.35fr 2fr;
      gap: 12px;
      margin-bottom: 14px;
    }
    .overall, .meta, .legend, .notice {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 14px;
      background: var(--panel);
    }
    .overall { border-left: 6px solid currentColor; }
    .overall.passed { color: var(--passed); background: var(--passed-bg); }
    .overall.warning { color: var(--warning); background: var(--warning-bg); }
    .overall.failed { color: var(--failed); background: var(--failed-bg); }
    .overall.unavailable { color: var(--unavailable); background: var(--unavailable-bg); }
    .overall-label { margin: 0 0 3px; color: var(--muted); font-size: 11px; text-transform: uppercase; letter-spacing: .08em; }
    .overall-value { margin: 0; font-size: 22px; font-weight: 700; }
    .metric-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin-top: 10px; }
    .metric { border-radius: 6px; padding: 6px; background: rgba(255,255,255,.72); text-align: center; }
    .metric strong { display: block; font-size: 17px; }
    .metric span { color: var(--muted); font-size: 10px; }
    .meta dl { display: grid; grid-template-columns: 140px 1fr; margin: 0; gap: 5px 12px; }
    .meta dt { color: var(--muted); }
    .meta dd { margin: 0; font-weight: 600; overflow-wrap: anywhere; }
    .legend { display: flex; flex-wrap: wrap; gap: 7px 14px; margin-bottom: 14px; padding: 9px 12px; background: white; }
    .legend-item { display: flex; align-items: center; gap: 7px; color: var(--muted); }
    .dot { width: 10px; height: 10px; border-radius: 50%; }
    .dot.passed { background: var(--passed); }
    .dot.warning { background: var(--warning); }
    .dot.failed { background: var(--failed); }
    .dot.unavailable { background: var(--unavailable); }
    .activities-block {
      margin: 0 0 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 11px 14px;
      background: #f8fafc;
    }
    .activities-block h2 { margin: 0 0 6px; font-size: 16px; color: var(--brand); }
    .activities-list { margin: 0; padding-left: 22px; }
    .activities-list li { margin: 3px 0; padding-left: 3px; }
    .activities-empty { margin: 0; color: var(--muted); font-style: italic; }
    .report-section { margin-top: 18px; }
    .report-section > h2 { margin: 0 0 7px; padding-bottom: 4px; border-bottom: 2px solid var(--brand); font-size: 18px; }
    .check-card { margin: 0 0 8px; border: 1px solid var(--line); border-left: 4px solid var(--unavailable); border-radius: 6px; padding: 10px 12px; break-inside: avoid; }
    .check-card.passed { border-left-color: var(--passed); }
    .check-card.warning { border-left-color: var(--warning); }
    .check-card.failed { border-left-color: var(--failed); }
    .check-heading { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
    h3 { margin: 0; font-size: 16px; }
    .status-badge { white-space: nowrap; border-radius: 999px; padding: 4px 10px; font-size: 11px; font-weight: 700; }
    .status-badge.passed { color: var(--passed); background: var(--passed-bg); }
    .status-badge.warning { color: var(--warning); background: var(--warning-bg); }
    .status-badge.failed { color: var(--failed); background: var(--failed-bg); }
    .status-badge.unavailable { color: var(--unavailable); background: var(--unavailable-bg); }
    .summary { margin: 4px 0 0; color: var(--muted); }
    .table-wrap { overflow-x: auto; margin-top: 7px; }
    table { width: 100%; border-collapse: collapse; font-size: 12px; }
    table.key-value th:first-child, table.key-value td:first-child { width: 32%; }
    th { color: #334155; background: #f1f4f7; text-align: left; font-weight: 650; }
    th, td { border: 1px solid var(--line); padding: 5px 6px; vertical-align: top; overflow-wrap: anywhere; }
    tr:nth-child(even) td { background: #fafbfc; }
    .notice { margin-top: 16px; color: var(--muted); font-size: 12px; }
    .notice strong { color: var(--ink); }
    footer { padding: 10px 34px; border-top: 1px solid var(--line); color: var(--muted); font-size: 11px; display: flex; justify-content: space-between; }
    @media (max-width: 760px) {
      .overview { grid-template-columns: 1fr; }
      .metric-grid { grid-template-columns: repeat(2, 1fr); }
      .meta dl { grid-template-columns: 1fr; gap: 3px; }
      main, .hero { padding-left: 22px; padding-right: 22px; }
    }
    @page { size: A4 portrait; margin: 7mm; }
    @media print {
      * {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      html, body { background: white; }
      body { font-size: 7.8pt; line-height: 1.22; }
      .page { max-width: none; margin: 0; box-shadow: none; }
      .hero {
        padding: 2.5mm 5mm 2mm;
        color: var(--ink);
        background: white;
        border-bottom-width: .6mm;
      }
      .eyebrow { margin-bottom: .5mm; font-size: 6.5pt; }
      h1 { font-size: 16pt; }
      .hero-subtitle { margin-top: .5mm; font-size: 7pt; }
      main { padding: 2.5mm 5mm 3.5mm; }
      .overview {
        grid-template-columns: 1.15fr 1.55fr;
        gap: 2mm;
        margin-bottom: 2mm;
        break-inside: avoid;
      }
      .overall, .meta, .legend, .notice { border-radius: 1mm; background: white; }
      .overall, .meta { padding: 2mm; }
      .overall {
        display: grid;
        grid-template-columns: 26mm minmax(0, 1fr);
        grid-template-rows: auto auto;
        align-items: center;
        column-gap: 2mm;
        border-left-width: 1mm;
      }
      .overall-label { margin-bottom: .4mm; font-size: 6.2pt; }
      .overall-value { font-size: 12.5pt; }
      .metric-grid {
        grid-column: 2;
        grid-row: 1 / span 2;
        gap: 1mm;
        margin-top: 0;
      }
      .metric { border: 1px solid var(--line); border-radius: 1mm; padding: .8mm .5mm; }
      .metric strong { font-size: 9pt; }
      .metric span { font-size: 5.8pt; }
      .meta dl {
        grid-template-columns: 29mm 1fr;
        gap: .7mm 2mm;
      }
      .legend {
        gap: 1mm 3mm;
        margin-bottom: 2mm;
        padding: 1.2mm 2mm;
        font-size: 6.8pt;
        break-inside: avoid;
      }
      .dot { width: 1.6mm; height: 1.6mm; }
      .activities-block {
        margin-bottom: 2.5mm;
        border-radius: 1mm;
        padding: 1.6mm 2.5mm;
        background: white;
        break-inside: avoid;
      }
      .activities-block h2 { margin-bottom: .8mm; font-size: 9pt; }
      .activities-list { padding-left: 4mm; columns: 2; column-gap: 6mm; }
      .activities-list li { margin: .4mm 0; padding-left: .3mm; break-inside: avoid; }
      .report-section { margin-top: 2.2mm; break-before: auto; }
      .report-section > h2 {
        margin-bottom: 1mm;
        padding-bottom: .5mm;
        font-size: 10.5pt;
        break-after: avoid;
      }
      .check-card {
        margin-bottom: 1.4mm;
        border-left-width: .9mm;
        border-radius: 1mm;
        padding: 1.5mm 2mm;
        break-inside: auto;
      }
      .check-card:not(:has(.table-wrap)) { break-inside: avoid; }
      .check-card:has(table.key-value) { break-inside: avoid; }
      .check-heading { gap: 2mm; break-after: avoid; }
      h3 { font-size: 8.5pt; }
      .status-badge {
        padding: .5mm 1.5mm;
        font-size: 6.2pt;
      }
      .summary {
        margin-top: .5mm;
        break-after: avoid;
      }
      .table-wrap {
        overflow: visible;
        margin-top: 1mm;
      }
      table {
        font-size: 7pt;
        line-height: 1.15;
      }
      thead { display: table-header-group; }
      tr { break-inside: avoid; }
      th, td {
        padding: .65mm .9mm;
        word-break: normal;
        overflow-wrap: anywhere;
      }
      table.wide-table,
      table.wide-table tbody {
        display: block;
      }
      table.wide-table thead { display: none; }
      table.wide-table tr {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        margin-bottom: .8mm;
        border: 1px solid var(--line);
        border-radius: 1mm;
        overflow: hidden;
        break-inside: avoid;
      }
      table.wide-table tr:last-child { margin-bottom: 0; }
      table.wide-table td {
        display: grid;
        grid-template-columns: minmax(25mm, 42%) minmax(0, 1fr);
        gap: 1mm;
        border: 0;
        border-bottom: 1px solid var(--line);
        background: white;
      }
      table.wide-table td:nth-child(odd) { border-right: 1px solid var(--line); }
      table.wide-table td::before {
        content: attr(data-label);
        color: #334155;
        font-weight: 650;
      }
      .notice {
        margin-top: 2mm;
        padding: 1.5mm 2mm;
        font-size: 6.8pt;
        break-inside: avoid;
      }
      footer {
        padding: 1.5mm 5mm 1mm;
        font-size: 6.2pt;
        break-inside: avoid;
      }
    }
  </style>
</head>
<body>
  <div class="page">
    <header class="hero">
      <p class="eyebrow">Technische Systemprüfung</p>
      <h1>PC-Prüfprotokoll</h1>
      <p class="hero-subtitle">Dokumentation der geprüften System-, Hardware-, Sicherheits- und Netzwerkzustände</p>
    </header>
    <main>
      <div class="overview">
        <section class="overall $overallClass">
          <p class="overall-label">Gesamtstatus</p>
          <p class="overall-value">$(Encode-Html $overallStatus)</p>
          <div class="metric-grid">
            <div class="metric"><strong>$($counts.Bestanden)</strong><span>Bestanden</span></div>
            <div class="metric"><strong>$($counts.Warnung)</strong><span>Warnungen</span></div>
            <div class="metric"><strong>$($counts.Fehler)</strong><span>Fehler</span></div>
            <div class="metric"><strong>$($counts.Nicht_verfügbar)</strong><span>Nicht verfügbar</span></div>
          </div>
        </section>
        <section class="meta">
          <dl>
            <dt>Computername</dt><dd>$(Encode-Html $computerName)</dd>
            <dt>Erstellt am</dt><dd>$(Encode-Html ($finishedAt.ToString('dd.MM.yyyy HH:mm:ss')))</dd>
            <dt>Prüfdauer</dt><dd>$(Encode-Html $durationText)</dd>
            <dt>Administratorrechte</dt><dd>$(Encode-Html $adminText)</dd>
          </dl>
        </section>
      </div>
      <div class="legend">
        <span class="legend-item"><i class="dot passed"></i>Bestanden</span>
        <span class="legend-item"><i class="dot warning"></i>Prüfung mit Hinweis</span>
        <span class="legend-item"><i class="dot failed"></i>Handlungsbedarf</span>
        <span class="legend-item"><i class="dot unavailable"></i>Nicht zuverlässig prüfbar</span>
      </div>
      <section class="activities-block">
        <h2>Durchgeführte Tätigkeiten</h2>
        $($activitiesBuilder.ToString())
      </section>
      $($cardsBuilder.ToString())
      <aside class="notice">
        <strong>Wichtiger Hinweis:</strong> Dieses Protokoll ist eine technische Momentaufnahme zum angegebenen Zeitpunkt.
        Es dokumentiert automatisiert erfassbare Zustände und ersetzt weder eine Herstellergarantie noch eine Zusicherung
        zukünftiger Fehlerfreiheit. „Nicht verfügbar“ bedeutet nicht automatisch, dass ein Defekt vorliegt.
      </aside>
    </main>
    <footer>
      <span>PC-Prüfprotokoll · $(Encode-Html $computerName)</span>
      <span>Erstellt am $(Encode-Html ($finishedAt.ToString('dd.MM.yyyy HH:mm')))</span>
    </footer>
  </div>
</body>
</html>
"@

$html | Set-Content -LiteralPath $htmlPath -Encoding UTF8

Write-Host ''
Write-Host ('Gesamtstatus: {0}' -f $overallStatus) -ForegroundColor $(switch ($overallStatus) {
    'Bestanden' { 'Green' }
    'Warnung' { 'Yellow' }
    'Fehler' { 'Red' }
    default { 'Gray' }
})
Write-Host ('HTML-Bericht: {0}' -f $htmlPath)
Write-Host ('Rohdaten:       {0}' -f $jsonPath)
if ($script:CollectionErrors.Count -gt 0) {
    Write-Host ('Hinweis: {0} Abfrage(n) konnten nicht vollständig ausgeführt werden; Details stehen in den Rohdaten.' -f $script:CollectionErrors.Count) -ForegroundColor Yellow
}

if (-not $NoOpen) {
    try { Start-Process -FilePath $htmlPath | Out-Null }
    catch { Write-Host 'Der Bericht konnte nicht automatisch geöffnet werden.' -ForegroundColor Yellow }
}

exit 0
