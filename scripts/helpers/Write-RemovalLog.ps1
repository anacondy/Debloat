# Structured logging: human-readable .log + machine-readable .json
$Script:LogFile  = $null
$Script:JsonFile = $null
$Global:LogActions = @()

function Initialize-RemovalLog {
    param(
        [string]$LogPath,
        [pscustomobject]$SystemInfo,
        [int]$LogRetention = 10
    )
    $stamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    if (-not $LogPath) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $LogPath = Join-Path $desktop "BloatRemoval-$stamp.log"
    }
    # Make sure the target folder exists (user may pass a custom -LogPath)
    $parent = Split-Path $LogPath -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $Script:LogFile  = $LogPath
    $Script:JsonFile = [IO.Path]::ChangeExtension($LogPath, '.json')
    $Global:LogActions = @()

    $hdr = @"
===============================================================
  Bloatware Removal Log
  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  Windows: $($SystemInfo.ProductName) $($SystemInfo.DisplayVer) (Build $($SystemInfo.Build))
  Architecture: $($SystemInfo.Architecture)
  Winget: $(if($SystemInfo.HasWinget){"Available (v$($SystemInfo.WingetVersion))"}else{'Not available'})
  Internet: $(if($SystemInfo.Online){'Connected'}else{'Offline'})
===============================================================

"@
    Set-Content -Path $Script:LogFile -Value $hdr -Encoding UTF8
    $Global:LogSystemInfo = $SystemInfo

    # Retention - keep last N, never delete silently without notice
    $dir = Split-Path $Script:LogFile -Parent
    $old = Get-ChildItem -Path $dir -Filter 'BloatRemoval-*.log' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -Skip $LogRetention
    foreach ($f in $old) {
        Write-Host "  Log retention: removing old log $($f.Name)" -ForegroundColor DarkGray
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        Remove-Item ([IO.Path]::ChangeExtension($f.FullName,'.json')) -Force -ErrorAction SilentlyContinue
    }
    return $Script:LogFile
}

function Write-RemovalLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','SUCCESS','WARN','FAIL','SKIP','HEADER')][string]$Level = 'INFO',
        [string]$Category,
        [string]$Package,
        [string]$Method,
        [switch]$NoConsole
    )
    $ts   = Get-Date -Format 'HH:mm:ss'
    $line = if ($Level -eq 'HEADER') { "`n-- $Message --" } else { "[$ts] $Message" }
    if ($Script:LogFile) { Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8 }

    if (-not $NoConsole) {
        $color = switch ($Level) {
            'SUCCESS' {'Green'} 'WARN' {'Yellow'} 'FAIL' {'Red'}
            'SKIP' {'DarkGray'} 'HEADER' {'Cyan'} default {'Gray'}
        }
        Write-Host $line -ForegroundColor $color
    }

    if ($Package) {
        $Global:LogActions += [pscustomobject]@{
            timestamp = (Get-Date).ToString('s')
            category  = $Category
            package   = $Package
            method    = $Method
            result    = $Level.ToLower()
            details   = $Message
        }
    }
}

function Complete-RemovalLog {
    param(
        [hashtable]$Validation = @{},
        [int]$ItemsRemoved = 0,
        [long]$SpaceFreedBytes = 0,
        [bool]$RebootRequired = $false
    )
    $gb = [math]::Round($SpaceFreedBytes/1GB, 2)
    $summary = @"

===============================================================
  SUMMARY
  Items removed: $ItemsRemoved
  Estimated space freed: ~$gb GB
  Validation: $(if($Validation.Values -contains $false){'SOME CHECKS FAILED'}else{'ALL PASSED'})
  Reboot recommended: $(if($RebootRequired){'YES'}else{'NO'})
===============================================================
"@
    if ($Script:LogFile) { Add-Content -Path $Script:LogFile -Value $summary -Encoding UTF8 }
    Write-Host $summary -ForegroundColor Cyan

    $json = [ordered]@{
        timestamp  = (Get-Date).ToString('s')
        system     = $Global:LogSystemInfo
        actions    = $Global:LogActions
        validation = $Validation
        summary    = [ordered]@{
            itemsRemoved    = $ItemsRemoved
            spaceFreedBytes = $SpaceFreedBytes
            rebootRequired  = $RebootRequired
        }
    }
    if ($Script:JsonFile) { $json | ConvertTo-Json -Depth 6 | Set-Content -Path $Script:JsonFile -Encoding UTF8 }
    return @{ Log = $Script:LogFile; Json = $Script:JsonFile }
}
