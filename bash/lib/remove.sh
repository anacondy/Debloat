#!/usr/bin/env bash
# remove.sh - removal engine with protection guard, retry and fallback.
# Mirrors scripts/helpers/Remove-SafeItem.ps1.

# shellcheck disable=SC2034  # consumed by the entry-point scripts
DRY_RUN=0        # when 1, print the command instead of running it
# shellcheck disable=SC2034  # consumed by the entry-point scripts
REBOOT_REQUIRED=0

# run_or_echo DESCRIPTION COMMAND...
run_or_echo() {
    local desc="$1"; shift
    if [[ "$DRY_RUN" == "1" ]]; then
        printf '       %s[dry-run]%s %s\n' "$C_GREY" "$C_RESET" "$desc"
        return 0
    fi
    "$@"
}

# --- Individual removal primitives ---------------------------------------

remove_appx() {
    local name="$1"
    [[ -z "$PS_EXE" ]] && return 127
    local esc="${name//\'/\'\'}"
    ps_run "\$ErrorActionPreference='Stop'
try {
  \$p = Get-AppxPackage -AllUsers -Name '$esc' -ErrorAction SilentlyContinue
  if (-not \$p) { Write-Output 'NOTFOUND'; exit 0 }
  \$p | Remove-AppxPackage -AllUsers -ErrorAction Stop
  Write-Output 'OK'
} catch { Write-Output ('ERR: ' + \$_.Exception.Message) }"
}

remove_appx_provisioned() {
    local name="$1"
    [[ -z "$PS_EXE" ]] && return 127
    local esc="${name//\'/\'\'}"
    ps_run "\$ErrorActionPreference='Stop'
try {
  \$p = Get-AppxProvisionedPackage -Online | Where-Object { \$_.DisplayName -like '$esc' }
  if (-not \$p) { Write-Output 'NOTFOUND'; exit 0 }
  \$p | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName \$_.PackageName -ErrorAction Stop | Out-Null }
  Write-Output 'OK'
} catch { Write-Output ('ERR: ' + \$_.Exception.Message) }"
}

set_service_mode() {
    local name="$1" mode="$2"
    win_tool sc stop "$name" >/dev/null 2>&1
    win_tool sc config "$name" "start=" "$mode" 2>&1 | tr -d '\r'
}

disable_task() {
    win_tool schtasks /change /tn "$1" /disable 2>&1 | tr -d '\r'
}

set_reg_dword() {
    local path="$1" name="$2" data="$3"
    win_tool reg add "$path" /v "$name" /t REG_DWORD /d "$data" /f 2>&1 | tr -d '\r'
}

remove_startup_entry() {
    local name="$1" hive
    for hive in 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' \
                'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; do
        win_tool reg delete "$hive" /v "$name" /f >/dev/null 2>&1 && return 0
    done
    return 1
}

disable_feature() {
    win_tool dism /online /disable-feature "/featurename:$1" /norestart 2>&1 | tr -d '\r'
}

uninstall_win32() {
    local display="$1"
    # Prefer winget (locale-safe, silent); fall back to PowerShell msiexec
    if [[ "$SYS_WINGET_BOOL" == "true" ]]; then
        local w
        w=$(winget.exe uninstall --name "$display" --silent \
              --accept-source-agreements --disable-interactivity 2>&1 | tr -d '\r')
        if grep -qiE 'successfully uninstalled|Successfully removed' <<<"$w"; then
            echo OK; return 0
        fi
    fi
    [[ -z "$PS_EXE" ]] && { echo "ERR: no winget and no PowerShell"; return 1; }
    local esc="${display//\'/\'\'}"
    ps_run "\$ErrorActionPreference='Stop'
\$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
         'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
\$app = Get-ItemProperty \$keys -EA SilentlyContinue | Where-Object { \$_.DisplayName -like '$esc' } | Select-Object -First 1
if (-not \$app) { Write-Output 'NOTFOUND'; exit 0 }
\$cmd = if (\$app.QuietUninstallString) { \$app.QuietUninstallString } else { \$app.UninstallString }
if (-not \$cmd) { Write-Output 'ERR: no uninstall string'; exit 0 }
try {
  if (\$cmd -match 'msiexec') {
    \$g = ([regex]::Match(\$cmd,'\{[0-9A-Fa-f\-]{36}\}')).Value
    if (-not \$g) { Write-Output 'ERR: no product code'; exit 0 }
    \$p = Start-Process msiexec.exe -ArgumentList \"/x \$g /qn /norestart\" -Wait -PassThru
    if (\$p.ExitCode -notin 0,1605,3010) { Write-Output (\"ERR: msiexec \" + \$p.ExitCode); exit 0 }
  } else {
    \$exe = \$cmd; \$a = ''
    if (\$cmd -match '^\"([^\"]+)\"\s*(.*)\$') { \$exe = \$Matches[1]; \$a = \$Matches[2] }
    elseif (\$cmd -match '^(\S+\.exe)\s*(.*)\$') { \$exe = \$Matches[1]; \$a = \$Matches[2] }
    if (\$a -notmatch '/S|/silent|/quiet|/qn') { \$a = (\$a + ' /S').Trim() }
    \$p = Start-Process \$exe -ArgumentList \$a -Wait -PassThru
    if (\$p.ExitCode -notin 0,1605,3010) { Write-Output (\"ERR: exit \" + \$p.ExitCode); exit 0 }
  }
  Write-Output 'OK'
} catch { Write-Output ('ERR: ' + \$_.Exception.Message) }"
}

cleanup_path() {
    local winpath="$1"
    [[ -z "$PS_EXE" ]] && return 127
    local esc="${winpath//\'/\'\'}"
    ps_run "\$p = [Environment]::ExpandEnvironmentVariables('$esc')
if (-not (Test-Path \$p)) { Write-Output 'NOTFOUND'; exit 0 }
Get-ChildItem \$p -Recurse -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
Write-Output 'OK'"
}

# --- Dispatcher ----------------------------------------------------------
# remove_item CATKEY NAME RISK TYPE EXTRA NOTE
# Echoes: success | skipped | failed
remove_item() {
    # shellcheck disable=SC2034  # risk kept for signature parity/readability
    local catkey="$1" name="$2" risk="$3" itype="$4" extra="$5"
    local cat="${CAT_TITLE[$catkey]:-Category $catkey}"

    # HARD GUARD - identical semantics to the PowerShell version
    if is_protected "$name"; then
        log_msg SKIP "$name ... PROTECTED, refusing to remove" "$name" "$cat" protected
        echo skipped; return
    fi
    if [[ "$itype" == "Win32" ]] && is_driver_related "$name"; then
        log_msg SKIP "$name ... DRIVER-RELATED, refusing without explicit consent" "$name" "$cat" driver-guard
        echo skipped; return
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        log_msg INFO "$name ... would run [$itype]" "$name" "$cat" "$itype"
        echo skipped; return
    fi

    local attempt=0 max=2 out=''
    while (( attempt <= max )); do
        attempt=$((attempt + 1))
        case "$itype" in
            Appx)
                out=$(remove_appx "$name")
                if [[ -z "$out" ]]; then out=$(remove_appx_provisioned "$name"); fi
                ;;
            Win32)     out=$(uninstall_win32 "$name") ;;
            Service)
                local before; before=$(service_start_mode "$name")
                if [[ "$before" == "absent" ]]; then out='NOTFOUND'
                else
                    set_service_mode "$name" "$extra" >/dev/null 2>&1
                    local after; after=$(service_start_mode "$name")
                    if [[ "$after" == "$extra" ]]; then out='OK'; else out="ERR: still $after"; fi
                fi
                ;;
            Task)
                if task_exists "$name"; then
                    if disable_task "$name" >/dev/null 2>&1; then out='OK'; else out='ERR: schtasks failed'; fi
                else out='NOTFOUND'; fi
                ;;
            Registry)
                local rpath rname rdata
                rpath="${extra%%::*}"
                rname="${extra#*::}"; rname="${rname%%::*}"
                rdata="${extra##*::}"
                if set_reg_dword "$rpath" "$rname" "$rdata" >/dev/null 2>&1; then out='OK'
                else out='ERR: reg add failed'; fi
                ;;
            Startup)
                if remove_startup_entry "$name"; then out='OK'; else out='NOTFOUND'; fi
                ;;
            Feature)
                if feature_enabled "$name"; then
                    if disable_feature "$name" >/dev/null 2>&1; then out='OK'; REBOOT_REQUIRED=1
                    else out='ERR: dism failed'; fi
                else out='NOTFOUND'; fi
                ;;
            Cleanup)   out=$(cleanup_path "$extra") ;;
            OneDrive)  out=$(remove_onedrive) ;;
            Shortcut)  out=$(remove_edge_shortcut) ;;
            *)         out="ERR: unknown type $itype" ;;
        esac

        case "$out" in
            *OK*)
                log_msg SUCCESS "$name ... SUCCESS ($itype)" "$name" "$cat" "$itype"
                case "$itype" in Win32|Feature|OneDrive) REBOOT_REQUIRED=1 ;; esac
                echo success; return ;;
            *NOTFOUND*)
                log_msg SKIP "$name ... NOT FOUND (already removed)" "$name" "$cat" "$itype"
                echo skipped; return ;;
            *)
                if (( attempt <= max )); then
                    log_msg WARN "$name ... attempt $attempt failed, retrying"
                    sleep 2
                    continue
                fi
                log_msg FAIL "$name ... FAILED (${out:-unknown error})" "$name" "$cat" "$itype"
                echo failed; return ;;
        esac
    done
}

remove_onedrive() {
    [[ -z "$PS_EXE" ]] && { echo "ERR: needs PowerShell"; return; }
    ps_run "Get-Process OneDrive -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
\$s = @(\"\$env:SystemRoot\SysWOW64\OneDriveSetup.exe\",\"\$env:SystemRoot\System32\OneDriveSetup.exe\") |
      Where-Object { Test-Path \$_ } | Select-Object -First 1
if (-not \$s) { Write-Output 'NOTFOUND'; exit 0 }
Start-Process \$s -ArgumentList '/uninstall' -Wait
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Force -EA SilentlyContinue
Write-Output 'OK'"
}

remove_edge_shortcut() {
    [[ -z "$PS_EXE" ]] && { echo "ERR: needs PowerShell"; return; }
    ps_run "\$p = @(\"\$env:PUBLIC\Desktop\Microsoft Edge.lnk\",\"\$env:USERPROFILE\Desktop\Microsoft Edge.lnk\") |
        Where-Object { Test-Path \$_ }
if (-not \$p) { Write-Output 'NOTFOUND'; exit 0 }
\$p | Remove-Item -Force -EA SilentlyContinue
Write-Output 'OK'"
}

# --- Safety net ----------------------------------------------------------
create_restore_point() {
    [[ -z "$PS_EXE" ]] && { log_msg WARN 'System Restore Point: SKIPPED (needs PowerShell)'; return 1; }
    local out
    out=$(ps_run "try {
  Enable-ComputerRestore -Drive \"\$env:SystemDrive\\\" -EA SilentlyContinue
  New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -EA SilentlyContinue | Out-Null
  Checkpoint-Computer -Description 'BloatRemoval bash $(date '+%Y-%m-%d %H:%M')' -RestorePointType MODIFY_SETTINGS -EA Stop
  Write-Output 'OK'
} catch { Write-Output ('ERR: ' + \$_.Exception.Message) }")
    if grep -q 'OK' <<<"$out"; then
        log_msg SUCCESS 'System Restore Point: CREATED'
        return 0
    fi
    log_msg FAIL "System Restore Point: FAILED ($out)"
    return 1
}

backup_registry() {
    local dir="$1" stamp branch file
    stamp=$(date '+%Y-%m-%d-%H%M%S')
    dir="$dir/$stamp"
    mkdir -p "$dir"
    for branch in \
        'HKLM\SOFTWARE\Policies\Microsoft\Windows' \
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' \
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' \
        'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' \
        'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'; do
        file="$dir/$(printf '%s' "$branch" | tr '\\:' '__').reg"
        win_tool reg export "$branch" "$(to_win_path "$file")" /y >/dev/null 2>&1
    done
    printf '%s' "$dir"
}

enable_defender() {
    [[ -z "$PS_EXE" ]] && { log_msg WARN 'Defender: cannot verify (needs PowerShell)'; return 1; }
    log_msg HEADER 'ANTIVIRUS HANDOFF'
    local out
    out=$(ps_run "Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -EA SilentlyContinue
try { Set-Service WinDefend -StartupType Automatic -EA Stop; Start-Service WinDefend -EA Stop } catch {}
try { Set-MpPreference -DisableRealtimeMonitoring \$false -EA Stop } catch {}
try { Update-MpSignature -EA Stop } catch {}
\$s = Get-Service WinDefend -EA SilentlyContinue
\$rt = \$false
try { \$rt = -not (Get-MpPreference).DisableRealtimeMonitoring } catch {}
Write-Output (\"SERVICE=\" + \$(if(\$s.Status -eq 'Running'){'1'}else{'0'}) + \" REALTIME=\" + \$(if(\$rt){'1'}else{'0'}))")

    if grep -q 'SERVICE=1' <<<"$out" && grep -q 'REALTIME=1' <<<"$out"; then
        log_msg SUCCESS 'Windows Defender ... ACTIVE (service running, real-time on)' 'WinDefend' 'Defender' 'Set-Service'
        return 0
    fi
    log_msg FAIL 'DEFENDER ACTIVATION INCOMPLETE - USER ACTION REQUIRED' 'WinDefend' 'Defender' 'Set-Service'
    printf '\n%s  *** CRITICAL WARNING ***%s\n' "$C_RED" "$C_RESET"
    printf '%s  Windows Defender could NOT be fully activated.%s\n' "$C_RED" "$C_RESET"
    printf '%s  Your PC may be unprotected. Open Windows Security and enable%s\n' "$C_RED" "$C_RESET"
    printf '%s  real-time protection manually, then reboot.%s\n\n' "$C_RED" "$C_RESET"
    return 1
}

# --- Post-removal validation --------------------------------------------
# Echoes a JSON object of the results.
validate_system() {
    log_msg HEADER 'VALIDATION'
    local json='{' first=1
    _check() {
        local key="$1" label="$2" ok="$3" fix="$4"
        local pad; pad=$(printf '%*s' $((30 - ${#label})) '' | tr ' ' '.')
        if [[ "$ok" == "1" ]]; then
            log_msg SUCCESS "$label $pad OK"
        else
            log_msg FAIL "$label $pad CHECK FAILED"
            log_msg WARN "   Fix: $fix"
        fi
        [[ "$first" == "0" ]] && json+=','
        first=0
        json+=$(printf '"%s":%s' "$key" "$([[ "$ok" == "1" ]] && echo true || echo false)")
    }

    local store=0 start=0 settings=0 search=0 update=0 defender=0 explorer=0
    if [[ -n "$PS_EXE" ]]; then
        local r
        r=$(ps_run "\$o=@()
\$o += 'STORE=' + \$(if(Get-AppxPackage -Name Microsoft.WindowsStore -EA SilentlyContinue){1}else{0})
\$o += 'START=' + \$(if(Get-AppxPackage -Name Microsoft.Windows.StartMenuExperienceHost -EA SilentlyContinue){1}else{0})
\$o += 'SETTINGS=' + \$(if(Get-AppxPackage -Name windows.immersivecontrolpanel -EA SilentlyContinue){1}else{0})
\$o += 'SEARCH=' + \$(if((Get-Service WSearch -EA SilentlyContinue).Status -eq 'Running'){1}else{0})
\$o += 'UPDATE=' + \$(if((Get-Service wuauserv -EA SilentlyContinue).StartType -ne 'Disabled'){1}else{0})
\$o += 'DEFENDER=' + \$(if((Get-Service WinDefend -EA SilentlyContinue).Status -eq 'Running'){1}else{0})
\$o += 'EXPLORER=' + \$(if(Test-Path \"\$env:SystemRoot\explorer.exe\"){1}else{0})
\$o -join ' '" | tr -d '\r')
        grep -q 'STORE=1'    <<<"$r" && store=1
        grep -q 'START=1'    <<<"$r" && start=1
        grep -q 'SETTINGS=1' <<<"$r" && settings=1
        grep -q 'SEARCH=1'   <<<"$r" && search=1
        grep -q 'UPDATE=1'   <<<"$r" && update=1
        grep -q 'DEFENDER=1' <<<"$r" && defender=1
        grep -q 'EXPLORER=1' <<<"$r" && explorer=1
    fi

    _check startMenu    'start Menu'    "$start"    'Get-AppxPackage -AllUsers *StartMenuExperienceHost* | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}'
    _check search       'search'        "$search"   'sc config WSearch start= auto && sc start WSearch'
    _check store        'store'         "$store"    'wsreset.exe'
    _check update       'update'        "$update"   'sc config wuauserv start= demand && sc start wuauserv'
    _check settings     'settings'      "$settings" 'Get-AppxPackage *immersivecontrolpanel* -AllUsers | Foreach {Add-AppxPackage -Register "$($_.InstallLocation)\AppXManifest.xml" -DisableDevelopmentMode}'
    _check fileExplorer 'file Explorer' "$explorer" 'sfc /scannow then DISM /Online /Cleanup-Image /RestoreHealth'
    _check defender     'defender'      "$defender" 'sc config WinDefend start= auto && sc start WinDefend'

    json+='}'
    printf '%s' "$json"
}
