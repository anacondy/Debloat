function Get-SystemInfo {
    <#
      .SYNOPSIS Detect edition, build, architecture, winget and connectivity.
      .OUTPUTS  PSCustomObject
    #>
    [CmdletBinding()]
    param()

    $cv = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $k  = Get-ItemProperty -Path $cv -ErrorAction SilentlyContinue

    $edition = $k.EditionID
    $isLTSC  = $edition -match 'EnterpriseS|IoTEnterpriseS'

    $arch = $env:PROCESSOR_ARCHITECTURE
    $arch = switch ($arch) { 'AMD64' {'x64'} 'ARM64' {'ARM64'} default {$arch} }

    $winget = $null
    $wgCmd  = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($wgCmd) { try { $winget = (& winget.exe --version) -replace '^v','' } catch { $winget = 'unknown' } }

    $online = $false
    try {
        $online = Test-Connection -ComputerName 'www.msftconnecttest.com' -Count 1 -Quiet -ErrorAction Stop
    } catch {
        try { $online = [bool](Invoke-WebRequest 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 5) } catch { $online = $false }
    }

    [pscustomobject]@{
        ProductName  = $k.ProductName -replace 'Windows 10','Windows 11'
        EditionID    = $edition
        DisplayVer   = $k.DisplayVersion            # 22H2 / 23H2 / 24H2 / 25H2
        Build        = "$($k.CurrentBuild).$($k.UBR)"
        BuildNumber  = [int]$k.CurrentBuild
        IsLTSC       = [bool]$isLTSC
        IsPro        = $edition -match 'Professional|Enterprise|Education'
        Architecture = $arch
        WingetVersion= $winget
        HasWinget    = [bool]$wgCmd
        Online       = [bool]$online
        IsAdmin      = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        ComputerName = $env:COMPUTERNAME
        Manufacturer = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer
        Model        = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Model
    }
}
