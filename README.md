# sysinfo-script

PowerShell script that collects a complete hardware and operating system report on Windows and saves it as a Markdown file on the user's Desktop.

## Usage

```powershell
powershell -ExecutionPolicy Bypass -File .\Get-SystemInfo.ps1
```

Custom output folder:

```powershell
.\Get-SystemInfo.ps1 -OutputPath C:\Reports
```

Output: `SystemInfo-<COMPUTERNAME>.md` in the output folder.

## Collected information

- System manufacturer, model, serial number, UUID, chassis type
- Windows edition, version, build, activation status, install date, uptime, time zone
- CPU model, manufacturer, cores, threads, clock speeds, cache, socket
- RAM modules including manufacturer, part number, speed, type and slot
- Graphics adapters with driver version, driver date, VRAM and current display mode
- Physical disks and volumes with capacity, media type, file system and health
- Monitors with model, size and year of manufacture
- Network adapters with link speed and MAC address, IP/gateway/DNS configuration
- Audio devices, keyboards, mice, cameras, printers, battery
- TPM, Secure Boot, BitLocker, Windows Defender, firewall status

## Requirements

- Windows 10 / 11 or Windows Server 2016+
- Windows PowerShell 5.1 or PowerShell 7+
- Administrator rights are optional and only improve detail (TPM state, BitLocker)
