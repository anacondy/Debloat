function Backup-Registry {
    <#
      .SYNOPSIS Export registry branches before modification.
    #>
    param(
        [string[]]$Branches = @(
            'HKLM\SOFTWARE\Policies\Microsoft\Windows'
            'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
            'HKCU\Software\Microsoft\Windows\CurrentVersion\Search'
            'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
        ),
        [string]$BackupDir
    )
    if (-not $BackupDir) { $BackupDir = Join-Path $PSScriptRoot '..\..\backups' }
    $stamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $dir   = Join-Path $BackupDir $stamp
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $saved = @()
    foreach ($b in $Branches) {
        $file = Join-Path $dir (($b -replace '[\\:]','_') + '.reg')
        $null = & reg.exe export $b $file /y 2>&1
        if (Test-Path $file) { $saved += $file }
    }

    # Snapshot the current Appx package list for restore purposes
    try {
        Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName, PackageFamilyName, Version |
            ConvertTo-Json -Depth 3 | Set-Content (Join-Path $dir 'AppxPackages.json') -Encoding UTF8
        Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName, Version |
            ConvertTo-Json -Depth 3 | Set-Content (Join-Path $dir 'AppxProvisioned.json') -Encoding UTF8
    } catch {}

    [pscustomobject]@{ Directory = $dir; Files = $saved }
}
