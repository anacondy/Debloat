function Get-BloatInventory {
    <#
      .SYNOPSIS Scan the system for installed bloat, excluding protected packages.
      .OUTPUTS  Array of finding objects: Category, Name, Display, Version, Type, Risk, Method, SizeBytes
    #>
    [CmdletBinding()]
    param([pscustomobject]$SystemInfo = (Get-SystemInfo))

    $findings = @()

    # --- Cache the live system state once (fast) -------------------------
    Write-Progress -Activity 'Scanning' -Status 'Appx packages' -PercentComplete 5
    $appx        = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    $appxProv    = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
    Write-Progress -Activity 'Scanning' -Status 'Installed programs' -PercentComplete 30
    $uninstKeys  = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $win32 = @(Get-ItemProperty $uninstKeys -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName })
    Write-Progress -Activity 'Scanning' -Status 'Services' -PercentComplete 55
    $services = @(Get-Service -ErrorAction SilentlyContinue)
    Write-Progress -Activity 'Scanning' -Status 'Scheduled tasks' -PercentComplete 70
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
    Write-Progress -Activity 'Scanning' -Status 'Startup entries' -PercentComplete 85
    $runKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
    $startup = foreach ($rk in $runKeys) {
        $p = Get-ItemProperty $rk -ErrorAction SilentlyContinue
        if ($p) { $p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
                  ForEach-Object { [pscustomobject]@{ Key=$rk; Name=$_.Name; Value=$_.Value } } }
    }
    $features = @()
    try { $features = @(Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue) } catch {}
    Write-Progress -Activity 'Scanning' -Completed

    foreach ($catKey in $Global:BloatCatalog.Keys) {
        $cat = $Global:BloatCatalog[$catKey]
        foreach ($item in $cat.Items) {

            switch ($item.T) {

                'Appx' {
                    if (Test-Protected $item.N) { continue }
                    $hits = $appx | Where-Object { $_.Name -like $item.N }
                    foreach ($h in $hits) {
                        if (Test-Protected $h.Name) { continue }
                        $size = 0
                        try { if ($h.InstallLocation -and (Test-Path $h.InstallLocation)) {
                            $size = (Get-ChildItem $h.InstallLocation -Recurse -Force -ErrorAction SilentlyContinue |
                                     Measure-Object Length -Sum).Sum } } catch {}
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$h.Name; Display=$h.Name
                            Version=$h.Version; Type='Appx'; Risk=$item.Risk
                            Method='Remove-AppxPackage'; SizeBytes=[long]$size
                            Extra=$h.PackageFullName; Note=$item.Note
                        }
                    }
                    $ph = $appxProv | Where-Object { $_.DisplayName -like $item.N }
                    foreach ($p in $ph) {
                        if (Test-Protected $p.DisplayName) { continue }
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$p.DisplayName
                            Display="$($p.DisplayName) (provisioned)"; Version=$p.Version
                            Type='AppxProvisioned'; Risk=$item.Risk
                            Method='Remove-AppxProvisionedPackage'; SizeBytes=0
                            Extra=$p.PackageName; Note=$item.Note
                        }
                    }
                }

                'Win32' {
                    $hits = $win32 | Where-Object { $_.DisplayName -like $item.N -or $_.DisplayName -like "$($item.N)*" }
                    foreach ($h in $hits) {
                        $risk = $item.Risk
                        $note = $item.Note
                        if (Test-DriverRelated $h.DisplayName) {
                            $risk = 'DANGER'
                            $note = 'Driver-related - removing may break hardware'
                        }
                        $size = 0
                        if ($h.EstimatedSize) { $size = [long]$h.EstimatedSize * 1KB }
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$h.DisplayName; Display=$h.DisplayName
                            Version=$h.DisplayVersion; Type='Win32'; Risk=$risk
                            Method=$(if($h.QuietUninstallString){'QuietUninstall'}elseif($h.UninstallString -match 'msiexec'){'msiexec'}else{'UninstallString'})
                            SizeBytes=$size
                            Extra=$(if($h.QuietUninstallString){$h.QuietUninstallString}else{$h.UninstallString})
                            Note=$note
                        }
                    }
                }

                'Service' {
                    $svc = $services | Where-Object { $_.Name -eq $item.N }
                    foreach ($s in $svc) {
                        $start = (Get-CimInstance Win32_Service -Filter "Name='$($s.Name)'" -ErrorAction SilentlyContinue).StartMode
                        if ($start -in @('Disabled')) { continue }
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$s.Name
                            Display="$($s.DisplayName) [service, currently $start]"
                            Version=''; Type='Service'; Risk=$item.Risk
                            Method="Set-Service -> $($item.Target)"; SizeBytes=0
                            Extra=$item.Target; Note=$item.Note
                        }
                    }
                }

                'Task' {
                    $t = $tasks | Where-Object { "$($_.TaskPath)$($_.TaskName)" -like $item.N -or $_.TaskName -like $item.N }
                    foreach ($x in $t) {
                        if ($x.State -eq 'Disabled') { continue }
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name="$($x.TaskPath)$($x.TaskName)"
                            Display="$($x.TaskName) [scheduled task]"; Version=''
                            Type='Task'; Risk=$item.Risk; Method='Disable-ScheduledTask'; SizeBytes=0
                            Extra=$x.TaskPath; Note=$item.Note
                        }
                    }
                }

                'Startup' {
                    $s = $startup | Where-Object { $_.Name -like $item.N -or $_.Value -like $item.N }
                    foreach ($x in $s) {
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$x.Name
                            Display="$($x.Name) [startup entry]"; Version=''
                            Type='Startup'; Risk=$item.Risk; Method='Remove registry Run value'; SizeBytes=0
                            Extra=$x.Key; Note=$item.Note
                        }
                    }
                }

                'Registry' {
                    $cur = $null
                    try { $cur = (Get-ItemProperty -Path $item.Path -Name $item.N -ErrorAction SilentlyContinue).$($item.N) } catch {}
                    if ($cur -ne $item.Value) {
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$item.N
                            Display="$($item.N) = $($item.Value) [registry tweak]"; Version=''
                            Type='Registry'; Risk=$item.Risk; Method='Set-ItemProperty'; SizeBytes=0
                            Extra=$item.Path; Note=$item.Note
                        }
                    }
                }

                'Feature' {
                    $f = $features | Where-Object { $_.FeatureName -like "$($item.N)*" -and $_.State -eq 'Enabled' }
                    foreach ($x in $f) {
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name=$x.FeatureName
                            Display="$($x.FeatureName) [optional feature]"; Version=''
                            Type='Feature'; Risk=$item.Risk; Method='Disable-WindowsOptionalFeature'; SizeBytes=0
                            Extra=''; Note=$item.Note
                        }
                    }
                }

                'Cleanup' {
                    if ($item.Path -and (Test-Path $item.Path)) {
                        $size = 0
                        try { $size = (Get-ChildItem $item.Path -Recurse -Force -ErrorAction SilentlyContinue |
                                       Measure-Object Length -Sum).Sum } catch {}
                        if ($size -gt 1MB) {
                            $findings += [pscustomobject]@{
                                CatKey=$catKey; Category=$cat.Title; Name=$item.N
                                Display="$($item.N) ($([math]::Round($size/1MB,1)) MB) - $($item.Path)"
                                Version=''; Type='Cleanup'; Risk=$item.Risk; Method='Delete files'
                                SizeBytes=[long]$size; Extra=$item.Path; Note=$item.Note
                            }
                        }
                    }
                }

                'OneDrive' {
                    $od = $win32 | Where-Object { $_.DisplayName -like 'Microsoft OneDrive*' }
                    foreach ($x in $od) {
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name='OneDrive'
                            Display="Microsoft OneDrive $($x.DisplayVersion)"; Version=$x.DisplayVersion
                            Type='OneDrive'; Risk='REVIEW'; Method='OneDriveSetup /uninstall'; SizeBytes=0
                            Extra=$x.UninstallString; Note='Move files out of OneDrive folder first'
                        }
                    }
                }

                'Shortcut' {
                    $paths = @("$env:PUBLIC\Desktop\Microsoft Edge.lnk", "$env:USERPROFILE\Desktop\Microsoft Edge.lnk")
                    foreach ($p in ($paths | Where-Object { Test-Path $_ })) {
                        $findings += [pscustomobject]@{
                            CatKey=$catKey; Category=$cat.Title; Name='Edge desktop shortcut'
                            Display="Edge desktop shortcut ($p)"; Version=''
                            Type='Shortcut'; Risk='SAFE'; Method='Delete shortcut'; SizeBytes=0
                            Extra=$p; Note=$null
                        }
                    }
                }
            }
        }
    }

    # Final protection sweep - belt and braces
    $findings | Where-Object { -not (Test-Protected $_.Name) }
}
