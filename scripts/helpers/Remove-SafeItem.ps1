function Remove-SafeItem {
    <#
      .SYNOPSIS Remove/disable one inventory item with retry + fallback methods.
      .PARAMETER Item  A finding object from Get-BloatInventory.
      .OUTPUTS 'success' | 'skipped' | 'failed'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][pscustomobject]$Item,
        [int]$Retries = 2,
        [switch]$UseWinget
    )

    if (Test-Protected $Item.Name) {
        Write-RemovalLog "$($Item.Display) ... PROTECTED, refusing to remove" -Level SKIP -Package $Item.Name -Category $Item.Category -Method 'protected'
        return 'skipped'
    }
    if (-not $PSCmdlet.ShouldProcess($Item.Display, $Item.Method)) { return 'skipped' }

    $attempt = 0
    while ($attempt -le $Retries) {
        $attempt++
        try {
            switch ($Item.Type) {

                'Appx' {
                    $pkg = Get-AppxPackage -AllUsers -Name $Item.Name -ErrorAction SilentlyContinue
                    if (-not $pkg) {
                        Write-RemovalLog "$($Item.Display) ... NOT FOUND (already removed)" -Level SKIP -Package $Item.Name -Category $Item.Category -Method 'Appx'
                        return 'skipped'
                    }
                    $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                }

                'AppxProvisioned' {
                    Remove-AppxProvisionedPackage -Online -PackageName $Item.Extra -ErrorAction Stop | Out-Null
                }

                'Win32' {
                    $cmd = $Item.Extra
                    if (-not $cmd) { throw 'No uninstall string' }
                    if ($cmd -match 'msiexec') {
                        $guid = ([regex]::Match($cmd,'\{[0-9A-Fa-f\-]{36}\}')).Value
                        if (-not $guid) { throw 'No MSI product code' }
                        $p = Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -PassThru
                        if ($p.ExitCode -notin 0,1605,3010) { throw "msiexec exit $($p.ExitCode)" }
                    } else {
                        $exe  = $cmd; $args = ''
                        if ($cmd -match '^"([^"]+)"\s*(.*)$') { $exe = $Matches[1]; $args = $Matches[2] }
                        elseif ($cmd -match '^(\S+\.exe)\s*(.*)$') { $exe = $Matches[1]; $args = $Matches[2] }
                        if ($args -notmatch '/S|/silent|/quiet|/qn') { $args = "$args /S /silent".Trim() }
                        $p = Start-Process $exe -ArgumentList $args -Wait -PassThru -ErrorAction Stop
                        if ($p.ExitCode -notin 0,3010,1605) { throw "uninstaller exit $($p.ExitCode)" }
                    }
                }

                'Service' {
                    $target = if ($Item.Extra) { $Item.Extra } else { 'Disabled' }
                    Stop-Service -Name $Item.Name -Force -ErrorAction SilentlyContinue
                    Set-Service -Name $Item.Name -StartupType $target -ErrorAction Stop
                }

                'Task' {
                    $leaf = Split-Path $Item.Name -Leaf
                    Disable-ScheduledTask -TaskPath $Item.Extra -TaskName $leaf -ErrorAction Stop | Out-Null
                }

                'Startup' {
                    Remove-ItemProperty -Path $Item.Extra -Name $Item.Name -Force -ErrorAction Stop
                }

                'Registry' {
                    # Value to write comes from the catalog lookup
                    $val = $null
                    foreach ($c in $Global:BloatCatalog.Values) {
                        foreach ($i in $c.Items) {
                            if ($i.T -eq 'Registry' -and $i.N -eq $Item.Name -and $i.Path -eq $Item.Extra) { $val = $i.Value }
                        }
                    }
                    if ($null -eq $val) { throw 'Registry value not found in catalog' }
                    if (-not (Test-Path $Item.Extra)) { New-Item -Path $Item.Extra -Force | Out-Null }
                    Set-ItemProperty -Path $Item.Extra -Name $Item.Name -Value $val -Type DWord -Force -ErrorAction Stop
                }

                'Feature' {
                    Disable-WindowsOptionalFeature -Online -FeatureName $Item.Name -NoRestart -ErrorAction Stop | Out-Null
                    $Global:RebootRequired = $true
                }

                'Cleanup' {
                    Get-ChildItem $Item.Extra -Recurse -Force -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }

                'OneDrive' {
                    Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    $setup = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe","$env:SystemRoot\System32\OneDriveSetup.exe") |
                             Where-Object { Test-Path $_ } | Select-Object -First 1
                    if ($setup) { Start-Process $setup -ArgumentList '/uninstall' -Wait }
                    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' |
                        ForEach-Object { Remove-ItemProperty $_ -Name 'OneDrive' -Force -ErrorAction SilentlyContinue }
                    foreach ($clsid in '{018D5C66-4533-4307-9B53-224DE2ED1FE6}','{04271989-C4D2-df11-959D-00C04FA06AB4}') {
                        foreach ($hive in 'HKCR:\CLSID','HKCR:\Wow6432Node\CLSID') {
                            $p = "$hive\$clsid"
                            if (Test-Path $p) { Set-ItemProperty $p -Name 'System.IsPinnedToNameSpaceTree' -Value 0 -ErrorAction SilentlyContinue }
                        }
                    }
                }

                'Shortcut' { Remove-Item $Item.Extra -Force -ErrorAction Stop }

                default { throw "Unknown item type $($Item.Type)" }
            }

            Write-RemovalLog "$($Item.Display) ... SUCCESS ($($Item.Method))" -Level SUCCESS -Package $Item.Name -Category $Item.Category -Method $Item.Method
            return 'success'
        }
        catch {
            $msg = $_.Exception.Message
            if ($msg -match 'not found|cannot find|No package') {
                Write-RemovalLog "$($Item.Display) ... NOT FOUND (already removed)" -Level SKIP -Package $Item.Name -Category $Item.Category -Method $Item.Method
                return 'skipped'
            }
            if ($attempt -le $Retries) {
                Write-RemovalLog "$($Item.Display) ... attempt $attempt failed ($msg) - retrying" -Level WARN
                Start-Sleep -Seconds 2
                continue
            }

            # Fallback: winget
            if ($UseWinget -and $Item.Type -in 'Win32','Appx') {
                try {
                    Write-RemovalLog "$($Item.Display) ... trying winget fallback" -Level WARN
                    $out = & winget.exe uninstall --name "$($Item.Name)" --silent --accept-source-agreements --disable-interactivity 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-RemovalLog "$($Item.Display) ... SUCCESS (winget)" -Level SUCCESS -Package $Item.Name -Category $Item.Category -Method 'winget'
                        return 'success'
                    }
                } catch {}
            }
            Write-RemovalLog "$($Item.Display) ... FAILED ($msg)" -Level FAIL -Package $Item.Name -Category $Item.Category -Method $Item.Method
            return 'failed'
        }
    }
}
