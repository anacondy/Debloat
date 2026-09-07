# Manual Commands — Advanced Reference

Copy-paste one-liners for people who don't want to run the whole script.
**All of these need an elevated PowerShell.** Make a restore point first:

```powershell
Enable-ComputerRestore -Drive "$env:SystemDrive\"
Checkpoint-Computer -Description "Manual debloat" -RestorePointType MODIFY_SETTINGS
```

## Recon (change nothing)

```powershell
# Every installed Appx package, alphabetical
Get-AppxPackage -AllUsers | Select Name, Version | Sort Name

# Packages baked into the image (reinstalled for every new user)
Get-AppxProvisionedPackage -Online | Select DisplayName, PackageName

# Installed desktop programs — fast method, no Win32_Product
Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,
                 HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
  Where DisplayName | Select DisplayName, DisplayVersion, Publisher | Sort DisplayName

# Registered antivirus products
Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct

# Startup entries
Get-CimInstance Win32_StartupCommand | Select Name, Command, Location

# Enabled optional features
Get-WindowsOptionalFeature -Online | Where State -eq Enabled | Select FeatureName
```

## Category 1 — Store bloat

```powershell
# Remove one app for all users
Get-AppxPackage -AllUsers -Name 'king.com.CandyCrushSaga' | Remove-AppxPackage -AllUsers

# ...and stop it coming back for new profiles
Get-AppxProvisionedPackage -Online | Where DisplayName -like '*CandyCrush*' |
  Remove-AppxProvisionedPackage -Online

# Bulk removal by package name
$junk = 'king.com.*','*TikTok*','*Netflix*','*SpotifyMusic*','*Disney*',
        '*Instagram*','*Facebook*','*WhatsApp*','Microsoft.BingNews',
        'Microsoft.BingWeather','Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.People',
        'Microsoft.WindowsMaps','Microsoft.SkypeApp','Microsoft.MicrosoftOfficeHub'
foreach ($j in $junk) {
  Get-AppxPackage -AllUsers -Name $j | Remove-AppxPackage -AllUsers -EA SilentlyContinue
  Get-AppxProvisionedPackage -Online | Where DisplayName -like $j |
    Remove-AppxProvisionedPackage -Online -EA SilentlyContinue
}
```

## Category 2 — Modern Windows 11 bloat

```powershell
# Copilot
Get-AppxPackage -AllUsers *Copilot* | Remove-AppxPackage -AllUsers
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' ShowCopilotButton 0
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot 1

# Widgets
Get-AppxPackage -AllUsers *WebExperience* | Remove-AppxPackage -AllUsers
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' TaskbarDa 0

# Teams (personal) and Phone Link
Get-AppxPackage -AllUsers MicrosoftTeams, MSTeams | Remove-AppxPackage -AllUsers
Get-AppxPackage -AllUsers Microsoft.YourPhone | Remove-AppxPackage -AllUsers

# Dev Home, Family, Power Automate
Get-AppxPackage -AllUsers *DevHome*, *MicrosoftFamily*, *PowerAutomateDesktop* |
  Remove-AppxPackage -AllUsers

Stop-Process -Name explorer -Force   # apply taskbar changes
```

## Category 3 — OEM bloat

```powershell
# Find the uninstall string, then run it silently
$app = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,
                        HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
       Where DisplayName -like '*SupportAssist*'
$app | Select DisplayName, QuietUninstallString, UninstallString

# MSI-based
msiexec /x '{PRODUCT-GUID-HERE}' /qn /norestart

# winget (locale-safe, preferred when available)
winget uninstall --id Dell.SupportAssist --silent
winget uninstall --name 'HP Support Assistant' --silent
```

## Category 4 — Antivirus + Defender handoff

```powershell
# Remove, then IMMEDIATELY restore Defender
winget uninstall --name 'McAfee' --silent

Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' DisableAntiSpyware -EA SilentlyContinue
Set-Service WinDefend -StartupType Automatic
Start-Service WinDefend
Set-MpPreference -DisableRealtimeMonitoring $false
Update-MpSignature
Start-MpScan -ScanType QuickScan

# Verify
Get-MpComputerStatus | Select AMServiceEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated
```

## Category 5 — Telemetry & privacy

```powershell
# Services
Stop-Service DiagTrack -Force; Set-Service DiagTrack -StartupType Disabled
Set-Service dmwappushservice -StartupType Disabled
Set-Service RetailDemo -StartupType Disabled
Set-Service DPS   -StartupType Manual     # Manual, NOT Disabled
Set-Service WerSvc -StartupType Manual

# Scheduled tasks
'\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
'\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
'\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
'\Microsoft\Windows\Application Experience\ProgramDataUpdater',
'\Microsoft\Windows\Feedback\Siuf\DmClient',
'\Microsoft\Windows\Windows Error Reporting\QueueReporting' | ForEach-Object {
  Disable-ScheduledTask -TaskPath (Split-Path $_ -Parent) -TaskName (Split-Path $_ -Leaf) -EA SilentlyContinue
}

# Registry
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' AllowTelemetry 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' PublishUserActivities 0
```

## Category 6 — Services

```powershell
Set-Service Fax           -StartupType Disabled
Set-Service RemoteRegistry -StartupType Disabled
Set-Service MapsBroker    -StartupType Disabled
Set-Service wisvc         -StartupType Disabled
Set-Service Spooler       -StartupType Disabled   # only if you never print

# Undo any of the above
Set-Service <Name> -StartupType Automatic; Start-Service <Name>
```

## Category 7 — Startup & tasks

```powershell
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Spotify' -EA SilentlyContinue
Get-ScheduledTask | Where TaskName -like 'GoogleUpdateTask*' | Disable-ScheduledTask
Get-ScheduledTask | Where TaskName -like 'Adobe*Update*'     | Disable-ScheduledTask
```

## Category 8 — OneDrive

```powershell
Stop-Process -Name OneDrive -Force -EA SilentlyContinue
Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" '/uninstall' -Wait
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' OneDrive -EA SilentlyContinue

# Hide from File Explorer sidebar
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
Set-ItemProperty 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' System.IsPinnedToNameSpaceTree 0

# Reinstall
Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
```

## Category 9 — Edge (safe tweaks only)

```powershell
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' StartupBoostEnabled 0
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' BackgroundModeEnabled 0
Remove-Item "$env:PUBLIC\Desktop\Microsoft Edge.lnk" -EA SilentlyContinue
# DO NOT uninstall Edge or WebView2.
```

## Category 10 — Cortana & search

```powershell
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' BingSearchEnabled 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' CortanaConsent 0
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' AllowCortana 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' IsDynamicSearchBoxEnabled 0
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 1  # icon only
Stop-Process -Name explorer -Force
```

## Category 11 — Xbox & gaming

```powershell
Get-AppxPackage -AllUsers *XboxGamingOverlay*, *XboxGameOverlay*, *XboxApp*,
                          *XboxSpeechToTextOverlay*, *Xbox.TCUI* |
  Remove-AppxPackage -AllUsers
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' AppCaptureEnabled 0
'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc' |
  ForEach-Object { Set-Service $_ -StartupType Manual -EA SilentlyContinue }
# Keep Microsoft.XboxIdentityProvider — many games sign in through it.
```

## Category 12 — Optional features

```powershell
'SMB1Protocol','MicrosoftWindowsPowerShellV2Root','TelnetClient','TFTP',
'Printing-XPSServices-Features','FaxServicesClientPackage',
'MSRDC-Infrastructure','WorkFolders-Client' | ForEach-Object {
  Disable-WindowsOptionalFeature -Online -FeatureName $_ -NoRestart -EA SilentlyContinue
}

# Re-enable
Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -All
```

## Category 13 — Disk cleanup

```powershell
Remove-Item "$env:TEMP\*"                -Recurse -Force -EA SilentlyContinue
Remove-Item "$env:SystemRoot\Temp\*"     -Recurse -Force -EA SilentlyContinue
Remove-Item "$env:SystemRoot\Minidump\*" -Recurse -Force -EA SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" -Recurse -Force -EA SilentlyContinue
Delete-DeliveryOptimizationCache -Force  # Win11 built-in cmdlet
cleanmgr /sageset:1 ; cleanmgr /sagerun:1

# Windows.old (frees 10-30 GB, but you lose feature-update rollback)
takeown /F "$env:SystemDrive\Windows.old" /R /A /D Y
icacls "$env:SystemDrive\Windows.old" /grant Administrators:F /T
Remove-Item "$env:SystemDrive\Windows.old" -Recurse -Force
```

## Verify everything still works

```powershell
Get-Service WSearch, wuauserv, WinDefend | Select Name, Status, StartType
Get-AppxPackage Microsoft.WindowsStore, Microsoft.Windows.StartMenuExperienceHost |
  Select Name, Status
sfc /scannow
```
