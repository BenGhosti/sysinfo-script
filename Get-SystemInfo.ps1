#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputPath = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'SilentlyContinue'
$generatedAt = Get-Date
$userLocale = (Get-Culture).DisplayName
$timeZone = (Get-TimeZone).DisplayName
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$md = [System.Collections.Generic.List[string]]::new()

function Get-CimData {
    param(
        [string]$ClassName,
        [string]$Namespace = 'root/cimv2',
        [string]$Filter
    )
    try {
        if ($Filter) {
            Get-CimInstance -ClassName $ClassName -Namespace $Namespace -Filter $Filter -ErrorAction Stop | Where-Object { $null -ne $_ }
        }
        else {
            Get-CimInstance -ClassName $ClassName -Namespace $Namespace -ErrorAction Stop | Where-Object { $null -ne $_ }
        }
    }
    catch { }
}

function Get-CimFirst {
    param(
        [string]$ClassName,
        [string]$Namespace = 'root/cimv2',
        [string]$Filter
    )
    $items = @(Get-CimData -ClassName $ClassName -Namespace $Namespace -Filter $Filter)
    if ($items.Count -gt 0) { return $items[0] }
    return $null
}

function Format-ByteSize {
    param([double]$Bytes)
    if ($Bytes -le 0) { return $null }
    if ($Bytes -ge 1PB) { return [string]::Format($culture, '{0:N2} PB', $Bytes / 1PB) }
    if ($Bytes -ge 1TB) { return [string]::Format($culture, '{0:N2} TB', $Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return [string]::Format($culture, '{0:N2} GB', $Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return [string]::Format($culture, '{0:N2} MB', $Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return [string]::Format($culture, '{0:N2} KB', $Bytes / 1KB) }
    return [string]::Format($culture, '{0:N0} B', $Bytes)
}

function Format-Frequency {
    param([double]$Megahertz)
    if ($Megahertz -le 0) { return $null }
    if ($Megahertz -ge 1000) { return [string]::Format($culture, '{0:N2} GHz', $Megahertz / 1000) }
    return [string]::Format($culture, '{0:N0} MHz', $Megahertz)
}

function Format-Megahertz {
    param([double]$Megahertz)
    if ($Megahertz -le 0) { return $null }
    return [string]::Format($culture, '{0:N0} MHz', $Megahertz)
}

function Format-Date {
    param($Date)
    if ($null -eq $Date) { return $null }
    return ([datetime]$Date).ToString('yyyy-MM-dd HH:mm', $culture)
}

function ConvertTo-MarkdownCell {
    param($Value)
    if ($null -eq $Value) { return 'N/A' }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return 'N/A' }
    $text = $text -replace '\r?\n', ' '
    return $text.Replace('|', '\|')
}

function Add-Heading {
    param([string]$Text)
    $md.Add("## $Text")
    $md.Add('')
}

function Add-KeyValueTable {
    param([System.Collections.IDictionary]$Data)
    $md.Add('| Property | Value |')
    $md.Add('| --- | --- |')
    foreach ($entry in $Data.GetEnumerator()) {
        $md.Add(('| {0} | {1} |' -f (ConvertTo-MarkdownCell $entry.Key), (ConvertTo-MarkdownCell $entry.Value)))
    }
    $md.Add('')
}

function Add-Table {
    param(
        [string[]]$Columns,
        [System.Collections.IEnumerable]$Rows
    )
    $md.Add('| ' + ($Columns -join ' | ') + ' |')
    $md.Add('| ' + (($Columns | ForEach-Object { '---' }) -join ' | ') + ' |')
    $rowCount = @($Rows).Count
    if ($rowCount -eq 0) {
        $md.Add('| ' + (($Columns | ForEach-Object { 'N/A' }) -join ' | ') + ' |')
    }
    else {
        foreach ($row in $Rows) {
            $cells = @($row) | ForEach-Object { ConvertTo-MarkdownCell $_ }
            $md.Add('| ' + ($cells -join ' | ') + ' |')
        }
    }
    $md.Add('')
}

$os = Get-CimFirst 'Win32_OperatingSystem'
$cs = Get-CimFirst 'Win32_ComputerSystem'
$bios = Get-CimFirst 'Win32_BIOS'
$board = Get-CimFirst 'Win32_BaseBoard'
$enclosure = Get-CimFirst 'Win32_SystemEnclosure'
$product = Get-CimFirst 'Win32_ComputerSystemProduct'
$currentVersion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$processors = @(Get-CimData 'Win32_Processor')
$memoryModules = @(Get-CimData 'Win32_PhysicalMemory')
$memoryArray = Get-CimFirst 'Win32_PhysicalMemoryArray'
$videoControllers = @(Get-CimData 'Win32_VideoController')
$physicalDisks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Sort-Object DeviceId)
$logicalVolumes = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter)
$diskDrives = @(Get-CimData 'Win32_DiskDrive')
$logicalDisks = @(Get-CimData 'Win32_LogicalDisk' -Filter 'DriveType = 3')
$keyboards = @(Get-CimData 'Win32_Keyboard')
$pointingDevices = @(Get-CimData 'Win32_PointingDevice')
$cameras = @(Get-CimData 'Win32_PnPEntity' -Filter "PNPClass = 'Camera'")
$soundDevices = @(Get-CimData 'Win32_SoundDevice')
$monitors = @(Get-CimData 'WmiMonitorID' 'root/wmi')
$monitorParams = @(Get-CimData 'WmiMonitorBasicDisplayParams' 'root/wmi')
$networkAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface } | Sort-Object Name)
$ipConfigurations = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter.Status -eq 'Up' })
$firewallProfiles = @(Get-NetFirewallProfile -ErrorAction SilentlyContinue)
$printers = @(Get-Printer -ErrorAction SilentlyContinue)
$pageFile = Get-CimFirst 'Win32_PageFileUsage'
$battery = Get-CimFirst 'Win32_Battery'
$batteryStatic = Get-CimFirst 'BatteryStaticData' 'root/wmi'
$batteryFull = Get-CimFirst 'BatteryFullChargedCapacity' 'root/wmi'
$tpm = $null
$tpmQueryFailed = $false
try {
    $tpm = Get-CimInstance -Namespace 'root/cimv2/security/microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop | Select-Object -First 1
}
catch {
    $tpmQueryFailed = $true
}
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
$license = Get-CimFirst 'SoftwareLicensingProduct' -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL"
$directXVersion = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\DirectX' -ErrorAction SilentlyContinue).Version
$bitLockerVolumes = @()
if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
    $bitLockerVolumes = @(Get-BitLockerVolume -ErrorAction SilentlyContinue)
}

$vramLookup = @{}
$adapterKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
foreach ($key in @(Get-ChildItem -Path $adapterKey -ErrorAction SilentlyContinue)) {
    try {
        $adapterProps = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop
        if ($adapterProps.DriverDesc -and $adapterProps.'HardwareInformation.qwMemorySize') {
            $vramLookup[$adapterProps.DriverDesc] = [uint64]$adapterProps.'HardwareInformation.qwMemorySize'
        }
    }
    catch { }
}

$hostname = $cs.Name
if (-not $hostname) { $hostname = $env:COMPUTERNAME }

$uptimeText = $null
if ($os.LastBootUpTime) {
    $uptimeSpan = $generatedAt - $os.LastBootUpTime
    $uptimeText = '{0} days, {1} hours, {2} minutes' -f [int]$uptimeSpan.TotalDays, $uptimeSpan.Hours, $uptimeSpan.Minutes
}

$displayVersion = $currentVersion.DisplayVersion
if (-not $displayVersion) { $displayVersion = $currentVersion.ReleaseId }
$buildNumber = $currentVersion.CurrentBuildNumber
if ($currentVersion.UBR) { $buildNumber = "$buildNumber.$($currentVersion.UBR)" }

$firmwareMode = $env:firmware_type
if (-not $firmwareMode) { $firmwareMode = 'Unknown' }

$licenseStatusMap = @{ 0 = 'Unlicensed'; 1 = 'Licensed'; 2 = 'Initial grace period'; 3 = 'Additional grace period'; 4 = 'Non-genuine grace period'; 5 = 'Notification'; 6 = 'Extended grace period' }
$activationText = $null
if ($license) {
    $licenseStatusText = $licenseStatusMap[[int]$license.LicenseStatus]
    if (-not $licenseStatusText) { $licenseStatusText = "Status $($license.LicenseStatus)" }
    $activationText = "$licenseStatusText ($($license.Description))"
}

$secureBootText = $null
try {
    $secureBootState = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name UEFISecureBootEnabled -ErrorAction Stop).UEFISecureBootEnabled
    if ($secureBootState -eq 1) { $secureBootText = 'Enabled' } else { $secureBootText = 'Disabled' }
}
catch { }
if (-not $secureBootText) {
    try {
        if (Confirm-SecureBootUEFI -ErrorAction Stop) { $secureBootText = 'Enabled' } else { $secureBootText = 'Disabled' }
    }
    catch { }
}
if (-not $secureBootText) {
    if ($firmwareMode -eq 'UEFI') { $secureBootText = 'Unknown (query failed)' } else { $secureBootText = 'Not supported (Legacy BIOS)' }
}

$tpmPresentText = 'No'
$tpmVersionText = $null
$tpmEnabledText = $null
if ($tpm) {
    $tpmPresentText = 'Yes'
    if ($tpm.SpecVersion) { $tpmVersionText = ($tpm.SpecVersion -split ',')[0].Trim() }
    if ($tpm.IsEnabled_InitialValue) { $tpmEnabledText = 'Yes' } else { $tpmEnabledText = 'No' }
}
elseif ($tpmQueryFailed) {
    $tpmDevice = Get-PnpDevice -Class 'SecurityDevices' -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'Trusted Platform Module' } | Select-Object -First 1
    if ($tpmDevice) {
        $tpmPresentText = 'Yes'
        if ($tpmDevice.FriendlyName -match '([0-9]+\.[0-9]+)') { $tpmVersionText = $Matches[1] }
    }
}

$defenderStatusText = $null
$defenderSignatureText = $null
$defenderScanText = $null
if ($defender) {
    if ($defender.RealTimeProtectionEnabled) { $defenderStatusText = 'Enabled' } else { $defenderStatusText = 'Disabled' }
    $defenderSignatureText = $defender.AntivirusSignatureVersion
    $defenderScanText = Format-Date $defender.QuickScanEndTime
}

$chassisMap = @{
    1 = 'Other'; 2 = 'Unknown'; 3 = 'Desktop'; 4 = 'Low Profile Desktop'; 5 = 'Pizza Box'; 6 = 'Mini Tower'; 7 = 'Tower'; 8 = 'Portable'; 9 = 'Laptop'; 10 = 'Notebook'; 11 = 'Hand Held'; 12 = 'Docking Station'; 13 = 'All in One'; 14 = 'Sub Notebook'; 15 = 'Space Saving'; 16 = 'Lunch Box'; 17 = 'Main System Chassis'; 18 = 'Expansion Chassis'; 19 = 'Sub Chassis'; 20 = 'Bus Expansion Chassis'; 21 = 'Peripheral Chassis'; 22 = 'Storage Chassis'; 23 = 'Rack Mount Chassis'; 24 = 'Sealed-Case PC'; 30 = 'Tablet'; 31 = 'Convertible'; 32 = 'Detachable'
}
$chassisType = $null
if (@($enclosure.ChassisTypes).Count -gt 0) {
    $chassisCode = [int]@($enclosure.ChassisTypes)[0]
    $chassisType = $chassisMap[$chassisCode]
    if (-not $chassisType) { $chassisType = "Unknown (code $chassisCode)" }
}

$totalMemory = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum
if (-not $totalMemory) { $totalMemory = $cs.TotalPhysicalMemory }
$totalMemoryText = Format-ByteSize ([double]$totalMemory)
$memoryTypeMap = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 34 = 'DDR5'; 35 = 'LPDDR5' }
$memoryFormFactorMap = @{ 1 = 'Other'; 2 = 'Unknown'; 8 = 'DIMM'; 12 = 'SODIMM'; 13 = 'SRIMM' }
$ramSpeed = $null
foreach ($module in $memoryModules) {
    if ($module.ConfiguredClockSpeed -gt 0) { $ramSpeed = $module.ConfiguredClockSpeed; break }
    if ($module.Speed -gt 0) { $ramSpeed = $module.Speed }
}

$mediaTypeMap = @{ 0 = 'Unspecified'; 3 = 'HDD'; 4 = 'SSD'; 5 = 'SCM' }
$busTypeMap = @{ 1 = 'SCSI'; 2 = 'ATAPI'; 3 = 'ATA'; 4 = 'IEEE 1394'; 5 = 'SSA'; 6 = 'USB'; 7 = 'Fibre Channel'; 8 = 'RAID'; 9 = 'iSCSI'; 10 = 'SAS'; 11 = 'SATA'; 12 = 'SD'; 13 = 'MMC'; 14 = 'Virtual'; 15 = 'File-backed Virtual'; 16 = 'Storage Spaces'; 17 = 'NVMe' }

$memorySummary = $totalMemoryText
if ($memoryModules.Count -gt 0) {
    $firstModuleType = $memoryTypeMap[[int]$memoryModules[0].SMBIOSMemoryType]
    if (-not $firstModuleType) { $firstModuleType = $memoryTypeMap[[int]$memoryModules[0].MemoryType] }
    $memorySummary = "$totalMemoryText"
    if ($firstModuleType) { $memorySummary += " $firstModuleType" }
    if ($ramSpeed -gt 0) { $memorySummary += " @ $(Format-Megahertz $ramSpeed)" }
    $memorySummary += " ($($memoryModules.Count) modules)"
}

$cpuSummary = $null
if ($processors.Count -gt 0) {
    $firstProcessor = $processors[0]
    $cpuSummary = "$(("$($firstProcessor.Name)").Trim()) | $($firstProcessor.NumberOfCores) cores / $($firstProcessor.NumberOfLogicalProcessors) threads | up to $(Format-Frequency $firstProcessor.MaxClockSpeed)"
}

$gpuSummary = (@($videoControllers | ForEach-Object { $_.Name }) -join ', ')
$storageSummary = $null
if ($physicalDisks.Count -gt 0) {
    $storageSummary = (@($physicalDisks | ForEach-Object { "$(("$($_.FriendlyName)").Trim()) ($(Format-ByteSize $_.Size))" }) -join ', ')
}
elseif ($diskDrives.Count -gt 0) {
    $storageSummary = (@($diskDrives | ForEach-Object { "$(("$($_.Model)").Trim()) ($(Format-ByteSize $_.Size))" }) -join ', ')
}
$displaySummary = $null
if ($videoControllers.Count -gt 0) {
    $displaySummary = $videoControllers[0].VideoModeDescription
    if ($videoControllers[0].CurrentRefreshRate) { $displaySummary = "$displaySummary @ $($videoControllers[0].CurrentRefreshRate) Hz" }
}

$md.Add("# $hostname - System Report")
$md.Add('')
$md.Add("Generated: $($generatedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
$md.Add('')

Add-Heading 'Summary'
$summaryData = [ordered]@{}
$summaryData['Computer'] = ("$($cs.Manufacturer) $($cs.Model)").Trim()
$summaryData['Operating System'] = ("$($os.Caption) $displayVersion (Build $buildNumber)").Trim()
$summaryData['Processor'] = $cpuSummary
$summaryData['Memory'] = $memorySummary
$summaryData['Graphics'] = $gpuSummary
$summaryData['Storage'] = $storageSummary
$summaryData['Display'] = $displaySummary
$summaryData['Uptime'] = $uptimeText
Add-KeyValueTable $summaryData

Add-Heading 'System'
Add-KeyValueTable ([ordered]@{
    'Host Name' = $hostname
    'Manufacturer' = $cs.Manufacturer
    'Model' = $cs.Model
    'System Family' = $cs.SystemFamily
    'Serial Number' = $bios.SerialNumber
    'Asset Tag' = $enclosure.SMBIOSAssetTag
    'System UUID' = $product.UUID
    'Chassis Type' = $chassisType
    'System Type' = $cs.SystemType
    'Domain / Workgroup' = $cs.Domain
    'Current User' = $cs.UserName
})

Add-Heading 'Operating System'
Add-KeyValueTable ([ordered]@{
    'Edition' = $os.Caption
    'Version' = $displayVersion
    'Build' = $buildNumber
    'Architecture' = $os.OSArchitecture
    'Install Date' = (Format-Date $os.InstallDate)
    'Last Boot' = (Format-Date $os.LastBootUpTime)
    'Uptime' = $uptimeText
    'System Locale' = $userLocale
    'Time Zone' = $timeZone
    'Page File' = if ($pageFile) { "$($pageFile.AllocatedBaseSize) MB allocated, $($pageFile.CurrentUsage) MB in use" } else { $null }
    'Activation' = $activationText
    'Firmware Mode' = $firmwareMode
})

Add-Heading 'Processor'
$processorRows = [System.Collections.Generic.List[object]]::new()
foreach ($processor in $processors) {
    $processorRows.Add([object[]]@(
        $processor.Name,
        $processor.Manufacturer,
        $processor.NumberOfCores,
        $processor.NumberOfLogicalProcessors,
        (Format-Frequency $processor.MaxClockSpeed),
        (Format-Frequency $processor.CurrentClockSpeed),
        (Format-ByteSize ([double]$processor.L2CacheSize * 1KB)),
        (Format-ByteSize ([double]$processor.L3CacheSize * 1KB)),
        $processor.SocketDesignation,
        $processor.AddressWidth
    ))
}
Add-Table -Columns @('Name', 'Manufacturer', 'Cores', 'Threads', 'Max Clock', 'Current Clock', 'L2 Cache', 'L3 Cache', 'Socket', 'Bits') -Rows $processorRows
$virtualizationText = $null
if ($processors.Count -gt 0) {
    if ($processors[0].VirtualizationFirmwareEnabled) { $virtualizationText = 'Enabled' } else { $virtualizationText = 'Disabled' }
}
Add-KeyValueTable ([ordered]@{
    'Virtualization (firmware)' = $virtualizationText
    'SLAT / EPT support' = $processors[0].SecondLevelAddressTranslationExtensions
    'Hypervisor present' = $cs.HypervisorPresent
})

Add-Heading 'Memory'
$memoryRows = [System.Collections.Generic.List[object]]::new()
foreach ($module in $memoryModules) {
    $moduleType = $memoryTypeMap[[int]$module.SMBIOSMemoryType]
    if (-not $moduleType) { $moduleType = $memoryTypeMap[[int]$module.MemoryType] }
    if (-not $moduleType -and $module.SMBIOSMemoryType) { $moduleType = "SMBIOS type $($module.SMBIOSMemoryType)" }
    $memoryRows.Add([object[]]@(
        $module.Manufacturer,
        $module.PartNumber,
        (Format-ByteSize ([double]$module.Capacity)),
        (Format-Megahertz $module.Speed),
        (Format-Megahertz $module.ConfiguredClockSpeed),
        $moduleType,
        $memoryFormFactorMap[[int]$module.FormFactor],
        $module.DeviceLocator
    ))
}
Add-Table -Columns @('Manufacturer', 'Part Number', 'Capacity', 'Rated Speed', 'Configured Speed', 'Type', 'Form Factor', 'Slot') -Rows $memoryRows
$totalSlots = $null
if ($memoryArray) { $totalSlots = $memoryArray.MemoryDevices }
Add-KeyValueTable ([ordered]@{
    'Total Installed' = $totalMemoryText
    'Modules' = $memoryModules.Count
    'Total Slots' = $totalSlots
    'Free Physical Memory' = (Format-ByteSize ([double]$os.FreePhysicalMemory * 1KB))
})

Add-Heading 'Graphics'
$gpuRows = [System.Collections.Generic.List[object]]::new()
foreach ($gpu in $videoControllers) {
    $vram = $vramLookup[$gpu.Name]
    if (-not $vram) { $vram = [uint64]$gpu.AdapterRAM }
    $vramText = $null
    if ($vram -gt 0) { $vramText = Format-ByteSize ([double]$vram) }
    $refreshText = $null
    if ($gpu.CurrentRefreshRate) { $refreshText = "$($gpu.CurrentRefreshRate) Hz" }
    $gpuRows.Add([object[]]@(
        $gpu.Name,
        $gpu.VideoProcessor,
        $gpu.DriverVersion,
        (Format-Date $gpu.DriverDate),
        $vramText,
        $gpu.VideoModeDescription,
        $refreshText,
        $gpu.Status
    ))
}
Add-Table -Columns @('Name', 'Video Processor', 'Driver Version', 'Driver Date', 'VRAM', 'Current Mode', 'Refresh Rate', 'Status') -Rows $gpuRows
if ($directXVersion) {
    Add-KeyValueTable ([ordered]@{ 'DirectX Version' = $directXVersion })
}

Add-Heading 'Storage'
$diskRows = [System.Collections.Generic.List[object]]::new()
if ($physicalDisks.Count -gt 0) {
    foreach ($disk in $physicalDisks) {
        $mediaText = $mediaTypeMap[[int]$disk.MediaType]
        $busText = $busTypeMap[[int]$disk.BusType]
        $diskRows.Add([object[]]@(
            $disk.FriendlyName,
            (Format-ByteSize ([double]$disk.Size)),
            $busText,
            $mediaText,
            "$($disk.HealthStatus)",
            $disk.SerialNumber
        ))
    }
}
else {
    foreach ($disk in $diskDrives) {
        $interfaceText = $disk.InterfaceType
        if ($disk.Model -match 'NVMe') { $interfaceText = 'NVMe' }
        elseif ($interfaceText -eq 'IDE') { $interfaceText = 'SATA' }
        $diskRows.Add([object[]]@(
            $disk.Model,
            (Format-ByteSize ([double]$disk.Size)),
            $interfaceText,
            $disk.MediaType,
            "$($disk.Status)",
            $disk.SerialNumber
        ))
    }
}
Add-Table -Columns @('Model', 'Capacity', 'Interface', 'Media Type', 'Health / Status', 'Serial') -Rows $diskRows
$volumeRows = [System.Collections.Generic.List[object]]::new()
if ($logicalVolumes.Count -gt 0) {
    foreach ($volume in $logicalVolumes) {
        $usedPercent = $null
        if ($volume.Size -gt 0) {
            $usedPercent = '{0:N1} %' -f (100.0 * ($volume.Size - $volume.SizeRemaining) / $volume.Size)
        }
        $volumeRows.Add([object[]]@(
            "$($volume.DriveLetter):",
            $volume.FileSystemLabel,
            $volume.FileSystem,
            (Format-ByteSize ([double]$volume.Size)),
            (Format-ByteSize ([double]$volume.SizeRemaining)),
            $usedPercent
        ))
    }
}
else {
    foreach ($volume in $logicalDisks) {
        $usedPercent = $null
        if ($volume.Size -gt 0) {
            $usedPercent = '{0:N1} %' -f (100.0 * ($volume.Size - $volume.FreeSpace) / $volume.Size)
        }
        $volumeRows.Add([object[]]@(
            $volume.DeviceID,
            $volume.VolumeName,
            $volume.FileSystem,
            (Format-ByteSize ([double]$volume.Size)),
            (Format-ByteSize ([double]$volume.FreeSpace)),
            $usedPercent
        ))
    }
}
Add-Table -Columns @('Drive', 'Label', 'File System', 'Size', 'Free', 'Used') -Rows $volumeRows

Add-Heading 'Displays'
$monitorRows = [System.Collections.Generic.List[object]]::new()
foreach ($monitor in $monitors) {
    $vendor = -join ($monitor.ManufacturerName | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ })
    $model = -join ($monitor.UserFriendlyName | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ })
    $serial = -join ($monitor.SerialNumberID | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ })
    if ($serial -match '^0+$') { $serial = $null }
    $size = $null
    $params = $monitorParams | Where-Object { $_.InstanceName -eq $monitor.InstanceName } | Select-Object -First 1
    if ($params -and $params.MaxHorizontalImageSize -gt 0 -and $params.MaxVerticalImageSize -gt 0) {
        $diagonal = [math]::Sqrt([math]::Pow([double]$params.MaxHorizontalImageSize, 2) + [math]::Pow([double]$params.MaxVerticalImageSize, 2)) / 2.54
        $size = '{0:N1} in' -f $diagonal
    }
    $year = $null
    if ($monitor.YearOfManufacture -gt 0) { $year = $monitor.YearOfManufacture }
    $monitorRows.Add([object[]]@($vendor, $model, $size, $year, $serial))
}
Add-Table -Columns @('Manufacturer', 'Model', 'Size', 'Year', 'Serial') -Rows $monitorRows

Add-Heading 'Network'
$adapterRows = [System.Collections.Generic.List[object]]::new()
foreach ($adapter in $networkAdapters) {
    $adapterRows.Add([object[]]@(
        $adapter.Name,
        $adapter.InterfaceDescription,
        "$($adapter.Status)",
        $adapter.LinkSpeed,
        $adapter.MacAddress
    ))
}
Add-Table -Columns @('Adapter', 'Description', 'Status', 'Link Speed', 'MAC Address') -Rows $adapterRows
$ipRows = [System.Collections.Generic.List[object]]::new()
foreach ($config in $ipConfigurations) {
    $ipv4 = ($config.IPv4Address.IPAddress) -join ', '
    $ipv6 = (($config.IPv6Address.IPAddress) -replace '%.*$', '') -join ', '
    $gateway = ($config.IPv4DefaultGateway.NextHop) -join ', '
    $dns = ($config.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }) -join ', '
    $ipRows.Add([object[]]@($config.InterfaceAlias, $ipv4, $ipv6, $gateway, $dns))
}
Add-Table -Columns @('Interface', 'IPv4', 'IPv6', 'Gateway', 'DNS') -Rows $ipRows

Add-Heading 'Audio'
$audioRows = [System.Collections.Generic.List[object]]::new()
foreach ($device in $soundDevices) {
    $audioRows.Add([object[]]@($device.Name, $device.Manufacturer, "$($device.Status)"))
}
Add-Table -Columns @('Name', 'Manufacturer', 'Status') -Rows $audioRows

if ($battery) {
    Add-Heading 'Battery'
    $batteryStatusMap = @{ 1 = 'Discharging'; 2 = 'On AC'; 3 = 'Fully Charged'; 4 = 'Low'; 5 = 'Critical'; 6 = 'Charging'; 7 = 'Charging (High)'; 8 = 'Charging (Low)'; 9 = 'Charging (Critical)'; 10 = 'Undefined'; 11 = 'Partially Charged' }
    $chargeText = $null
    if ($null -ne $battery.EstimatedChargeRemaining) { $chargeText = "$($battery.EstimatedChargeRemaining) %" }
    $remainingText = $null
    if ($battery.EstimatedRunTime -and $battery.EstimatedRunTime -lt 71582788) { $remainingText = "$($battery.EstimatedRunTime) minutes" }
    $designCapacityText = $null
    $fullCapacityText = $null
    $batteryHealthText = $null
    if ($batteryStatic -and $batteryStatic.DesignedCapacity -gt 0) {
        $designCapacityText = "$([math]::Round($batteryStatic.DesignedCapacity / 1000.0)) Wh"
        if ($batteryFull -and $batteryFull.FullChargedCapacity -gt 0) {
            $fullCapacityText = "$([math]::Round($batteryFull.FullChargedCapacity / 1000.0)) Wh"
            $batteryHealthText = '{0:N1} %' -f (100.0 * $batteryFull.FullChargedCapacity / $batteryStatic.DesignedCapacity)
        }
    }
    Add-KeyValueTable ([ordered]@{
        'Name' = $battery.Name
        'Status' = $batteryStatusMap[[int]$battery.BatteryStatus]
        'Charge' = $chargeText
        'Remaining Time' = $remainingText
        'Design Capacity' = $designCapacityText
        'Full Charge Capacity' = $fullCapacityText
        'Battery Health' = $batteryHealthText
    })
}

Add-Heading 'Security'
Add-KeyValueTable ([ordered]@{
    'TPM Present' = $tpmPresentText
    'TPM Version' = $tpmVersionText
    'TPM Enabled' = $tpmEnabledText
    'Secure Boot' = $secureBootText
    'Defender Real-Time Protection' = $defenderStatusText
    'Defender Signature Version' = $defenderSignatureText
    'Defender Last Quick Scan' = $defenderScanText
})
if ($bitLockerVolumes.Count -gt 0) {
    $bitLockerRows = [System.Collections.Generic.List[object]]::new()
    foreach ($bitLockerVolume in $bitLockerVolumes) {
        $bitLockerRows.Add([object[]]@(
            $bitLockerVolume.MountPoint,
            "$($bitLockerVolume.VolumeStatus)",
            "$($bitLockerVolume.ProtectionStatus)",
            "$($bitLockerVolume.EncryptionPercentage) %"
        ))
    }
    Add-Table -Columns @('Volume', 'Status', 'Protection', 'Encrypted') -Rows $bitLockerRows
}
$firewallRows = [System.Collections.Generic.List[object]]::new()
foreach ($profile in $firewallProfiles) {
    $firewallRows.Add([object[]]@($profile.Name, "$($profile.Enabled)"))
}
Add-Table -Columns @('Firewall Profile', 'Enabled') -Rows $firewallRows

Add-Heading 'BIOS & Motherboard'
Add-KeyValueTable ([ordered]@{
    'BIOS Vendor' = $bios.Manufacturer
    'BIOS Version' = $bios.SMBIOSBIOSVersion
    'BIOS Release Date' = (Format-Date $bios.ReleaseDate)
    'Motherboard Manufacturer' = $board.Manufacturer
    'Motherboard Model' = $board.Product
    'Motherboard Version' = $board.Version
    'Motherboard Serial' = $board.SerialNumber
    'Firmware Type' = $firmwareMode
})

Add-Heading 'Peripherals'
$peripheralRows = [System.Collections.Generic.List[object]]::new()
foreach ($keyboard in $keyboards) {
    $peripheralRows.Add([object[]]@('Keyboard', $keyboard.Description, "$($keyboard.Status)"))
}
foreach ($pointer in $pointingDevices) {
    $peripheralRows.Add([object[]]@('Mouse / Pointer', $pointer.Name, "$($pointer.Status)"))
}
foreach ($camera in $cameras) {
    $peripheralRows.Add([object[]]@('Camera', $camera.Name, "$($camera.Status)"))
}
if ($printers.Count -gt 0) {
    foreach ($printer in $printers) {
        $peripheralRows.Add([object[]]@('Printer', $printer.Name, "$($printer.DriverName) | $($printer.PortName)"))
    }
}
else {
    foreach ($printer in @(Get-CimData 'Win32_Printer')) {
        $peripheralRows.Add([object[]]@('Printer', $printer.Name, "$($printer.DriverName) | $($printer.PortName)"))
    }
}
Add-Table -Columns @('Category', 'Device', 'Details') -Rows $peripheralRows

$md.Add('---')
$md.Add('')
$md.Add('*Report generated by Get-SystemInfo.ps1*')
$md.Add('')

$fileName = "SystemInfo-$hostname.md"
if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}
$reportPath = Join-Path -Path $OutputPath -ChildPath $fileName
[System.IO.File]::WriteAllText($reportPath, ([string]::Join([Environment]::NewLine, $md)), (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Report saved to: $reportPath"
