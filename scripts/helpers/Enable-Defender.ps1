function Enable-Defender {
    <#
      .SYNOPSIS Re-activate Windows Defender after removing third-party AV.
    #>
    [CmdletBinding()]
    param([switch]$SkipScan)

    $result = [ordered]@{ Service=$false; RealTime=$false; Definitions=$false; Scan=$false }

    try {
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -ErrorAction SilentlyContinue
        Set-Service -Name WinDefend -StartupType Automatic -ErrorAction Stop
        Start-Service -Name WinDefend -ErrorAction Stop
        $result.Service = (Get-Service WinDefend).Status -eq 'Running'
        Write-RemovalLog 'Windows Defender service ... STARTED' -Level SUCCESS -Package 'WinDefend' -Category 'Defender' -Method 'Set-Service'
    } catch {
        Write-RemovalLog "Windows Defender service ... FAILED ($($_.Exception.Message))" -Level FAIL -Package 'WinDefend' -Category 'Defender'
    }

    try {
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
        $result.RealTime = -not (Get-MpPreference).DisableRealtimeMonitoring
        Write-RemovalLog 'Defender real-time protection ... ENABLED' -Level SUCCESS -Package 'RealtimeProtection' -Category 'Defender'
    } catch {
        Write-RemovalLog "Defender real-time protection ... FAILED ($($_.Exception.Message))" -Level FAIL -Package 'RealtimeProtection' -Category 'Defender'
    }

    try {
        Update-MpSignature -ErrorAction Stop
        $result.Definitions = $true
        Write-RemovalLog 'Defender definitions ... UPDATED' -Level SUCCESS
    } catch {
        Write-RemovalLog 'Defender definitions ... could not update (offline?)' -Level WARN
    }

    if (-not $SkipScan) {
        try {
            Write-RemovalLog 'Defender quick scan ... running (this may take a few minutes)' -Level INFO
            Start-MpScan -ScanType QuickScan -ErrorAction Stop
            $result.Scan = $true
            Write-RemovalLog 'Defender quick scan ... COMPLETE' -Level SUCCESS
        } catch {
            Write-RemovalLog "Defender quick scan ... FAILED ($($_.Exception.Message))" -Level WARN
        }
    }

    if (-not ($result.Service -and $result.RealTime)) {
        Write-Host "`n  *** CRITICAL WARNING ***" -ForegroundColor Red
        Write-Host "  Windows Defender could NOT be fully activated." -ForegroundColor Red
        Write-Host "  Your PC may currently be unprotected. Open Windows Security" -ForegroundColor Red
        Write-Host "  (Start > Windows Security > Virus & threat protection) and enable" -ForegroundColor Red
        Write-Host "  real-time protection manually, then reboot.`n" -ForegroundColor Red
        Write-RemovalLog 'DEFENDER ACTIVATION INCOMPLETE - USER ACTION REQUIRED' -Level FAIL
    } else {
        Write-Host "  Defender is now active and protecting your PC." -ForegroundColor Green
    }
    return $result
}
