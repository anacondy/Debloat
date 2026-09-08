<#
.SYNOPSIS
    Windows 11 Bloatware Removal - safe, reversible, interactive.

.DESCRIPTION
    Detects and removes Windows 11 bloatware, OEM junk, trial antivirus,
    telemetry and modern bloat (Copilot, Widgets, Teams, Phone Link...).
    Creates a System Restore Point and registry backups first, never touches
    protected system packages, validates the system afterwards, and logs
    everything.

.PARAMETER Force
    Skip interactive confirmations (still honours protected list).

.PARAMETER DryRun
    Show what would happen and exit. This is the DEFAULT behaviour unless
    you confirm at the prompt.

.PARAMETER Categories
    Comma-separated category numbers to process non-interactively, e.g. 1,2,5.

.PARAMETER SafeOnly
    Only act on items marked SAFE.

.PARAMETER SkipRestorePoint
    Skip the System Restore Point (NOT recommended).

.PARAMETER LogPath
    Custom log file path.

.PARAMETER LogRetention
    Number of previous logs to keep (default 10).

.EXAMPLE
    irm https://raw.githubusercontent.com/anacondy/Debloat/main/scripts/Remove-Bloat.ps1 | iex

.EXAMPLE
    .\Remove-Bloat.ps1 -SafeOnly -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,
    [switch]$DryRun,
    [string[]]$Categories,
    [switch]$SafeOnly,
    [switch]$SkipRestorePoint,
    [switch]$SkipDefenderScan,
    [switch]$PreventReprovisioning,
    [string]$LogPath,
    [int]$LogRetention = 10
)

$ErrorActionPreference = 'Stop'
$Global:RebootRequired = $false

# -- Load helpers (local files or download when run via irm|iex) -----------
$RepoRaw   = 'https://raw.githubusercontent.com/anacondy/Debloat/main'
$HelperDir = Join-Path $PSScriptRoot 'helpers'
$Helpers   = 'BloatData','Get-SystemInfo','Write-RemovalLog','Backup-Registry',
             'Get-BloatInventory','Remove-SafeItem','Enable-Defender',
             'Test-CoreFunctions','Get-DriverInfo'

foreach ($h in $Helpers) {
    $local = Join-Path $HelperDir "$h.ps1"
    if (Test-Path $local) { . $local }
    else {
        try   { .([scriptblock]::Create((Invoke-RestMethod "$RepoRaw/scripts/helpers/$h.ps1"))) }
        catch { Write-Host "FATAL: cannot load helper '$h'. Clone the repo and run locally." -ForegroundColor Red; return }
    }
}

function Write-Banner {
    Write-Host ''
    Write-Host '  ===============================================================' -ForegroundColor Cyan
    Write-Host '    WINDOWS 11 BLOATWARE REMOVAL' -ForegroundColor Cyan
    Write-Host '    Safe  |  Reversible  |  Logged' -ForegroundColor DarkCyan
    Write-Host '  ===============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Get-RiskColor { param($r) switch ($r) { 'SAFE'{'Green'} 'REVIEW'{'Yellow'} 'DANGER'{'Red'} default{'Gray'} } }

# == STEP 1: ADMIN =========================================================
Write-Banner
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host '  Administrator rights are required.' -ForegroundColor Yellow
    if ($PSCommandPath) {
        Write-Host '  Attempting to relaunch elevated...' -ForegroundColor Yellow
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList @(
                '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
            ) | Out-Null
            return
        } catch { }
    }
    Write-Host ''
    Write-Host '  Please do this:' -ForegroundColor White
    Write-Host '    1. Press Windows key, type: Terminal' -ForegroundColor White
    Write-Host '    2. Right-click "Terminal" > Run as administrator' -ForegroundColor White
    Write-Host '    3. Paste the command again' -ForegroundColor White
    Write-Host ''
    return
}

# == STEP 2: DETECT ========================================================
Write-Host '  [1/6] Detecting system...' -ForegroundColor Cyan
$sys = Get-SystemInfo
$logFile = Initialize-RemovalLog -LogPath $LogPath -SystemInfo $sys -LogRetention $LogRetention

Write-Host "        OS       : $($sys.ProductName) $($sys.DisplayVer) (Build $($sys.Build))"
Write-Host "        Edition  : $($sys.EditionID)$(if($sys.IsLTSC){' [LTSC]'})"
Write-Host "        Arch     : $($sys.Architecture)"
Write-Host "        Device   : $($sys.Manufacturer) $($sys.Model)"
Write-Host "        Winget   : $(if($sys.HasWinget){"v$($sys.WingetVersion)"}else{'NOT AVAILABLE (Appx/MSI fallback)'})" -ForegroundColor $(if($sys.HasWinget){'Gray'}else{'Yellow'})
Write-Host "        Internet : $(if($sys.Online){'Connected'}else{'OFFLINE (network steps skipped)'})" -ForegroundColor $(if($sys.Online){'Gray'}else{'Yellow'})
Write-Host "        Log      : $logFile" -ForegroundColor DarkGray

if ($sys.BuildNumber -lt 22000) {
    Write-Host '  WARNING: This does not look like Windows 11. Continue at your own risk.' -ForegroundColor Yellow
    if (-not $Force) { $c = Read-Host '  Continue? (y/N)'; if ($c -ne 'y') { return } }
}

# == STEP 3: SCAN ==========================================================
Write-Host ''
Write-Host '  [2/6] Scanning for bloat (protected packages excluded)...' -ForegroundColor Cyan
$inventory = @(Get-BloatInventory -SystemInfo $sys)

if (-not $inventory.Count) {
    Write-Host '  Nothing found - your system already looks clean.' -ForegroundColor Green
    Complete-RemovalLog | Out-Null
    return
}

$drivers = @(Get-DriverInfo)
Write-Host "        Found $($inventory.Count) removable item(s) across $(($inventory.Category | Select-Object -Unique).Count) categories."
if ($drivers.Count) { Write-Host "        Protected $($drivers.Count) driver-related program(s) from removal." -ForegroundColor DarkGray }

# == STEP 4/5: CATEGORIZE + DISPLAY ========================================
Write-Host ''
Write-Host '  [3/6] Findings' -ForegroundColor Cyan
$byCat = $inventory | Group-Object CatKey | Sort-Object { [int]$_.Name }
foreach ($g in $byCat) {
    $title = $Global:BloatCatalog[$g.Name].Title
    $mb = [math]::Round((($g.Group | Measure-Object SizeBytes -Sum).Sum)/1MB,0)
    Write-Host ''
    Write-Host ("  [{0}] {1}  ({2} items{3})" -f $g.Name, $title, $g.Count, $(if($mb -gt 0){", ~$mb MB"}else{''})) -ForegroundColor White
    foreach ($i in $g.Group) {
        Write-Host ('       {0,-6} ' -f $i.Risk) -ForegroundColor (Get-RiskColor $i.Risk) -NoNewline
        Write-Host ('{0}' -f $i.Display) -NoNewline
        Write-Host ("  [{0}]" -f $i.Method) -ForegroundColor DarkGray
        if ($i.Note) { Write-Host "              note: $($i.Note)" -ForegroundColor DarkYellow }
    }
}

# == STEP 6: MENU ==========================================================
$selected = @()
if ($Categories) {
    $selected = $inventory | Where-Object { $_.CatKey -in $Categories }
} elseif ($Force -and $SafeOnly) {
    $selected = $inventory | Where-Object { $_.Risk -eq 'SAFE' }
} else {
    while ($true) {
        Write-Host ''
        Write-Host '  ---------------------------------------------------------------' -ForegroundColor DarkCyan
        Write-Host '   [1-13] Choose categories (comma separated, e.g. 1,2,5)' -ForegroundColor White
        Write-Host '   [A]    Remove all SAFE items only  (recommended)' -ForegroundColor Green
        Write-Host '   [C]    Custom item-by-item selection' -ForegroundColor White
        Write-Host '   [S]    Scan only - write report and exit' -ForegroundColor White
        Write-Host '   [Q]    Quit without changes' -ForegroundColor White
        Write-Host '  ---------------------------------------------------------------' -ForegroundColor DarkCyan
        $choice = (Read-Host '  Your choice').Trim()

        if ($choice -match '^[Qq]$') { Write-Host '  Cancelled. Nothing changed.' -ForegroundColor Yellow; return }
        if ($choice -match '^[Ss]$') {
            Write-RemovalLog "Scan-only mode. $($inventory.Count) items found." -Level INFO
            Complete-RemovalLog | Out-Null
            Write-Host "  Report saved to $logFile" -ForegroundColor Green
            return
        }
        if ($choice -match '^[Aa]$') { $selected = $inventory | Where-Object { $_.Risk -eq 'SAFE' }; break }
        if ($choice -match '^[Cc]$') {
            $i = 0
            $indexed = $inventory | ForEach-Object { $i++; $_ | Add-Member -NotePropertyName Idx -NotePropertyValue $i -PassThru -Force }
            foreach ($x in $indexed) {
                Write-Host ('  {0,3}. ' -f $x.Idx) -NoNewline
                Write-Host ('{0,-6} ' -f $x.Risk) -ForegroundColor (Get-RiskColor $x.Risk) -NoNewline
                Write-Host $x.Display
            }
            $nums = (Read-Host '  Enter numbers to remove (comma separated)') -split ',' | ForEach-Object { $_.Trim() }
            $selected = $indexed | Where-Object { "$($_.Idx)" -in $nums }
            break
        }
        $cats = $choice -split ',' | ForEach-Object { $_.Trim() }
        $selected = $inventory | Where-Object { $_.CatKey -in $cats }
        if ($selected.Count) { break }
        Write-Host '  Invalid choice, try again.' -ForegroundColor Yellow
    }
}

if ($SafeOnly) { $selected = $selected | Where-Object { $_.Risk -eq 'SAFE' } }
$selected = @($selected)
if (-not $selected.Count) { Write-Host '  Nothing selected. Exiting.' -ForegroundColor Yellow; return }

# Gaming question
if ($selected | Where-Object { $_.CatKey -eq '11' }) {
    if (-not $Force) {
        $g = Read-Host '  Do you play games or use Xbox / Game Pass? (y/N)'
        if ($g -eq 'y') {
            Write-Host '  Skipping all Xbox/Gaming items to keep your games working.' -ForegroundColor Yellow
            $selected = $selected | Where-Object { $_.CatKey -ne '11' }
        }
    }
}

# == STEP 7: DRY RUN =======================================================
Write-Host ''
Write-Host '  [4/6] DRY RUN - these exact actions would run:' -ForegroundColor Cyan
foreach ($i in $selected) {
    Write-Host ('       {0,-6} ' -f $i.Risk) -ForegroundColor (Get-RiskColor $i.Risk) -NoNewline
    Write-Host ('{0}  ->  {1}' -f $i.Display, $i.Method)
}
$totalMb = [math]::Round((($selected | Measure-Object SizeBytes -Sum).Sum)/1MB,0)
Write-Host ''
Write-Host "        $($selected.Count) item(s), estimated space freed ~$totalMb MB" -ForegroundColor White

if ($DryRun) { Write-Host '  -DryRun specified. No changes made.' -ForegroundColor Yellow; Complete-RemovalLog | Out-Null; return }

# == STEP 8: CONFIRM =======================================================
if (-not $Force) {
    $danger = @($selected | Where-Object { $_.Risk -eq 'DANGER' })
    if ($danger.Count) {
        Write-Host ''
        Write-Host "  WARNING: $($danger.Count) DANGER item(s) selected. These can break hardware or features." -ForegroundColor Red
        $d = Read-Host '  Type EXACTLY "I ACCEPT" to include them, anything else skips them'
        if ($d -ne 'I ACCEPT') {
            $selected = $selected | Where-Object { $_.Risk -ne 'DANGER' }
            Write-Host '  DANGER items skipped.' -ForegroundColor Yellow
        }
    }
    Write-Host ''
    $ok = Read-Host '  Proceed with removal? (y/N)'
    if ($ok -ne 'y') { Write-Host '  Cancelled. Nothing changed.' -ForegroundColor Yellow; return }
}

# == STEP 9: BACKUP ========================================================
Write-Host ''
Write-Host '  [5/6] Creating safety net...' -ForegroundColor Cyan
if (-not $SkipRestorePoint) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Bypass the 24h restore point frequency limit
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
            -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
        Checkpoint-Computer -Description "BloatRemoval $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-RemovalLog 'System Restore Point: CREATED' -Level SUCCESS
    } catch {
        Write-RemovalLog "System Restore Point: FAILED ($($_.Exception.Message))" -Level FAIL
        if (-not $Force) {
            $c = Read-Host '  Restore point failed. Continue anyway? (y/N)'
            if ($c -ne 'y') { return }
        }
    }
} else { Write-RemovalLog 'System Restore Point: SKIPPED by user (-SkipRestorePoint)' -Level WARN }

$bk = Backup-Registry
Write-RemovalLog "Registry Backup: SAVED -> $($bk.Directory)" -Level SUCCESS

# == STEP 10: EXECUTE ======================================================
Write-Host ''
Write-Host '  [6/6] Removing...' -ForegroundColor Cyan
$removed=0; $failed=0; $skipped=0; $freed=0L; $avRemoved=$false
$n=0
foreach ($cat in ($selected | Group-Object CatKey | Sort-Object { [int]$_.Name })) {
    Write-RemovalLog "CATEGORY $($cat.Name): $($Global:BloatCatalog[$cat.Name].Title)" -Level HEADER
    foreach ($item in $cat.Group) {
        $n++
        Write-Progress -Activity 'Removing bloat' -Status $item.Display -PercentComplete ([int](100*$n/$selected.Count))
        $res = Remove-SafeItem -Item $item -UseWinget:$sys.HasWinget -Confirm:$false
        switch ($res) {
            'success' { $removed++; $freed += $item.SizeBytes; if ($cat.Name -eq '4') { $avRemoved = $true }
                        if ($item.Type -in 'Feature','Win32','OneDrive') { $Global:RebootRequired = $true } }
            'failed'  { $failed++ }
            default   { $skipped++ }
        }
    }
}
Write-Progress -Activity 'Removing bloat' -Completed

# == STEP 11: DEFENDER HANDOFF =============================================
if ($avRemoved) {
    Write-Host ''
    Write-RemovalLog 'ANTIVIRUS HANDOFF' -Level HEADER
    Enable-Defender -SkipScan:$SkipDefenderScan | Out-Null
    $Global:RebootRequired = $true
}

# == Optional: prevent reprovisioning ======================================
$doPrevent = $PreventReprovisioning
if (-not $Force -and -not $PreventReprovisioning) {
    $p = Read-Host '  Prevent bloat from returning after Windows updates? (y/N)'
    $doPrevent = ($p -eq 'y')
}
if ($doPrevent) {
    Write-RemovalLog 'REPROVISIONING PREVENTION' -Level HEADER
    $tweaks = @(
        @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';N='DisableWindowsConsumerFeatures';V=1}
        @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';N='DisableCloudOptimizedContent';V=1}
        @{P='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';N='DisableConsumerAccountStateContent';V=1}
        @{P='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='SilentInstalledAppsEnabled';V=0}
        @{P='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='PreInstalledAppsEnabled';V=0}
        @{P='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager';N='OemPreInstalledAppsEnabled';V=0}
    )
    foreach ($t in $tweaks) {
        try {
            if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
            Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type DWord -Force
            Write-RemovalLog "$($t.N) = $($t.V) ... SET" -Level SUCCESS -Package $t.N -Category 'Reprovisioning'
        } catch { Write-RemovalLog "$($t.N) ... FAILED" -Level FAIL }
    }
    Write-Host '  Note: major Windows feature updates may still restore some apps - just re-run this script.' -ForegroundColor DarkYellow
}

# == STEP 12: VALIDATE =====================================================
$validation = Test-CoreFunctions
$vHash = @{}; $validation.GetEnumerator() | ForEach-Object { $vHash[$_.Key] = $_.Value }

# == STEP 13: SUMMARY ======================================================
Write-Host ''
Write-Host "  Removed: $removed   Skipped: $skipped   Failed: $failed" -ForegroundColor White
$files = Complete-RemovalLog -Validation $vHash -ItemsRemoved $removed -SpaceFreedBytes $freed -RebootRequired $Global:RebootRequired
Write-Host "  Log : $($files.Log)"  -ForegroundColor DarkGray
Write-Host "  JSON: $($files.Json)" -ForegroundColor DarkGray
Write-Host "  Registry backup: $($bk.Directory)" -ForegroundColor DarkGray
Write-Host ''
Write-Host '  To restore anything: .\Restore-Bloat.ps1' -ForegroundColor Cyan
if ($Global:RebootRequired) { Write-Host '  >>> REBOOT RECOMMENDED to finish cleanup. <<<' -ForegroundColor Yellow }
Write-Host ''
