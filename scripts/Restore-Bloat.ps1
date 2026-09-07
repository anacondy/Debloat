<#
.SYNOPSIS
    Restore items removed by Remove-Bloat.ps1.
.DESCRIPTION
    Three levels of restore:
      1. System Restore Point (fastest full rollback)
      2. Registry backup import (undo tweaks / services / startup entries)
      3. Reinstall Appx packages (from a backup snapshot or the Store)
.EXAMPLE
    .\Restore-Bloat.ps1
#>
[CmdletBinding()]
param([string]$BackupDir, [switch]$AllAppx)

$ErrorActionPreference = 'Continue'
if (-not $BackupDir) { $BackupDir = Join-Path $PSScriptRoot '..\backups' }

function Test-Admin { ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
if (-not (Test-Admin)) { Write-Host 'Run this in an ADMIN PowerShell window.' -ForegroundColor Red; return }

Write-Host ''
Write-Host '  RESTORE MENU' -ForegroundColor Cyan
Write-Host '   [1] Roll back with a System Restore Point   (undoes everything)'
Write-Host '   [2] Re-import a registry backup             (undoes tweaks/services)'
Write-Host '   [3] Re-register all built-in Windows apps   (fixes Start/Store/Settings)'
Write-Host '   [4] Reinstall a specific app from the Store'
Write-Host '   [5] Reinstall OneDrive'
Write-Host '   [Q] Quit'
$c = (Read-Host '  Choice').Trim()

switch ($c) {
  '1' {
        $pts = Get-ComputerRestorePoint | Sort-Object CreationTime -Descending
        if (-not $pts) { Write-Host '  No restore points found.' -ForegroundColor Yellow; break }
        $pts | Select-Object SequenceNumber, Description, @{n='Created';e={$_.ConvertToDateTime($_.CreationTime)}} | Format-Table -AutoSize
        $n = Read-Host '  SequenceNumber to restore (PC will reboot)'
        if ($n) { Restore-Computer -RestorePoint $n }
      }
  '2' {
        $dirs = Get-ChildItem $BackupDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        if (-not $dirs) { Write-Host "  No backups in $BackupDir" -ForegroundColor Yellow; break }
        $i=0; $dirs | ForEach-Object { $i++; Write-Host "   $i. $($_.Name)" }
        $sel = [int](Read-Host '  Backup number')
        $d = $dirs[$sel-1]
        Get-ChildItem $d.FullName -Filter *.reg | ForEach-Object {
            Write-Host "   importing $($_.Name)"
            & reg.exe import $_.FullName 2>&1 | Out-Null
        }
        Write-Host '  Registry restored. Reboot recommended.' -ForegroundColor Green
      }
  '3' {
        Write-Host '  Re-registering all provisioned apps...' -ForegroundColor Cyan
        Get-AppxPackage -AllUsers | ForEach-Object {
            try { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop }
            catch {}
        }
        Write-Host '  Done. Reboot and check Start Menu / Store / Settings.' -ForegroundColor Green
      }
  '4' {
        $name = Read-Host '  App name or winget ID (e.g. Microsoft.WindowsCalculator or 9WZDNCRFJBMP)'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id $name --source msstore --accept-package-agreements --accept-source-agreements
        } else {
            Write-Host "  Winget unavailable. Open the Microsoft Store and search for: $name" -ForegroundColor Yellow
        }
      }
  '5' {
        $setup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe","$env:SystemRoot\System32\OneDriveSetup.exe") |
                 Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($setup) { Start-Process $setup } else { Start-Process 'https://www.microsoft.com/microsoft-365/onedrive/download' }
      }
  default { Write-Host '  Cancelled.' }
}
