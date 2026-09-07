function Test-CoreFunctions {
    <#
      .SYNOPSIS Post-removal validation of core Windows functionality.
    #>
    [CmdletBinding()]
    param()

    $r = [ordered]@{}
    Write-RemovalLog 'VALIDATION' -Level HEADER

    $checks = [ordered]@{
        startMenu    = { [bool](Get-AppxPackage -Name 'Microsoft.Windows.StartMenuExperienceHost' -ErrorAction SilentlyContinue) -and
                         [bool](Get-Process StartMenuExperienceHost -ErrorAction SilentlyContinue) }
        search       = { (Get-Service WSearch -ErrorAction SilentlyContinue).Status -eq 'Running' -or
                         [bool](Get-Process SearchHost -ErrorAction SilentlyContinue) }
        store        = { [bool](Get-AppxPackage -Name 'Microsoft.WindowsStore' -ErrorAction SilentlyContinue) }
        update       = { (Get-Service wuauserv -ErrorAction SilentlyContinue).StartType -ne 'Disabled' }
        settings     = { [bool](Get-AppxPackage -Name 'windows.immersivecontrolpanel' -ErrorAction SilentlyContinue) }
        fileExplorer = { Test-Path "$env:SystemRoot\explorer.exe" }
        defender     = { (Get-Service WinDefend -ErrorAction SilentlyContinue).Status -eq 'Running' }
    }

    $fixes = @{
        startMenu    = 'Run: Get-AppxPackage -AllUsers *StartMenuExperienceHost* | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}'
        search       = 'Run: Set-Service WSearch -StartupType Automatic; Start-Service WSearch'
        store        = 'Run: wsreset.exe  - or reinstall Store via: winget install 9WZDNCRFJBMP'
        update       = 'Run: Set-Service wuauserv -StartupType Manual; Start-Service wuauserv'
        settings     = 'Run: Get-AppxPackage *immersivecontrolpanel* -AllUsers | Foreach {Add-AppxPackage -Register "$($_.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode}'
        fileExplorer = 'Run: sfc /scannow  then  DISM /Online /Cleanup-Image /RestoreHealth'
        defender     = 'Open Windows Security and enable real-time protection, or run: Start-Service WinDefend'
    }

    foreach ($k in $checks.Keys) {
        $ok = $false
        try { $ok = [bool](& $checks[$k]) } catch { $ok = $false }
        $r[$k] = $ok
        $label = ($k -creplace '([A-Z])',' $1')
        $pad   = ('.' * [Math]::Max(2, 30 - $label.Length))
        if ($ok) { Write-RemovalLog "$label $pad OK" -Level SUCCESS }
        else {
            Write-RemovalLog "$label $pad CHECK FAILED" -Level FAIL
            Write-RemovalLog "   Fix: $($fixes[$k])" -Level WARN
        }
    }
    return $r
}
