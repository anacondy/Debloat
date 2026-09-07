function Get-DriverInfo {
    <#
      .SYNOPSIS List installed programs that are driver-related (never auto-remove these).
    #>
    [CmdletBinding()]
    param()
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and (Test-DriverRelated $_.DisplayName) } |
        ForEach-Object {
            [pscustomobject]@{
                Name      = $_.DisplayName
                Publisher = $_.Publisher
                Version   = $_.DisplayVersion
                Risk      = 'DANGER'
                Reason    = 'Driver / hardware support software - removal can break audio, Wi-Fi, touchpad, graphics or Windows Hello'
            }
        } | Sort-Object Name -Unique
}
