#!/usr/bin/env bash
# detect.sh - Windows system information gathering from bash.
# Uses reg.exe (fast, always present) and falls back to PowerShell.

# get_system_info -> populates SYS_* globals
get_system_info() {
    SYS_PRODUCT='unknown'; SYS_EDITION='unknown'; SYS_DISPLAYVER=''
    SYS_BUILD='0'; SYS_BUILDNUM=0; SYS_ARCH='unknown'
    SYS_WINGET='Not available'; SYS_WINGET_BOOL=false
    SYS_ONLINE='Offline'; SYS_ONLINE_BOOL=false
    SYS_IS_LTSC=0; SYS_IS_PRO=0

    local cv='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    local out
    out=$(win_tool reg query "$cv" 2>/dev/null | tr -d '\r')

    if [[ -n "$out" ]]; then
        SYS_PRODUCT=$(awk '/[[:space:]]ProductName[[:space:]]/{ $1=""; $2=""; sub(/^[[:space:]]+/,""); print; exit }' <<<"$out")
        SYS_EDITION=$(awk '/[[:space:]]EditionID[[:space:]]/{ print $NF; exit }' <<<"$out")
        SYS_DISPLAYVER=$(awk '/[[:space:]]DisplayVersion[[:space:]]/{ print $NF; exit }' <<<"$out")
        local cb ubr
        cb=$(awk '/[[:space:]]CurrentBuild[[:space:]]/{ print $NF; exit }' <<<"$out")
        ubr=$(awk '/[[:space:]]UBR[[:space:]]/{ print $NF; exit }' <<<"$out")
        [[ "$ubr" =~ ^0x ]] && ubr=$((ubr))
        SYS_BUILD="${cb:-0}.${ubr:-0}"
        SYS_BUILDNUM="${cb:-0}"
    elif [[ -n "$PS_EXE" ]]; then
        # Fallback: single PowerShell call
        local psout
        psout=$(ps_run '$k=Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"; "{0}`n{1}`n{2}`n{3}`n{4}" -f $k.ProductName,$k.EditionID,$k.DisplayVersion,$k.CurrentBuild,$k.UBR' | tr -d '\r')
        SYS_PRODUCT=$(sed -n '1p' <<<"$psout")
        SYS_EDITION=$(sed -n '2p' <<<"$psout")
        SYS_DISPLAYVER=$(sed -n '3p' <<<"$psout")
        SYS_BUILDNUM=$(sed -n '4p' <<<"$psout")
        SYS_BUILD="$(sed -n '4p' <<<"$psout").$(sed -n '5p' <<<"$psout")"
    fi

    # Numeric guard so arithmetic comparisons never explode
    [[ "$SYS_BUILDNUM" =~ ^[0-9]+$ ]] || SYS_BUILDNUM=0

    case "$SYS_EDITION" in
        EnterpriseS|IoTEnterpriseS) SYS_IS_LTSC=1 ;;
    esac
    case "$SYS_EDITION" in
        Professional*|Enterprise*|Education*|ProEducation*) SYS_IS_PRO=1 ;;
    esac

    # Architecture
    local pa="${PROCESSOR_ARCHITECTURE:-}"
    if [[ -z "$pa" ]]; then
        pa=$(win_tool reg query 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' /v PROCESSOR_ARCHITECTURE 2>/dev/null \
             | tr -d '\r' | awk '/PROCESSOR_ARCHITECTURE/{print $NF; exit}')
    fi
    case "$pa" in
        AMD64) SYS_ARCH='x64' ;;
        ARM64) SYS_ARCH='ARM64' ;;
        x86)   SYS_ARCH='x86' ;;
        *)     SYS_ARCH="${pa:-unknown}" ;;
    esac

    # winget
    if command -v winget.exe >/dev/null 2>&1 || command -v winget >/dev/null 2>&1; then
        local wv
        wv=$(winget.exe --version 2>/dev/null || winget --version 2>/dev/null)
        wv=$(printf '%s' "$wv" | tr -d '\r\n')
        SYS_WINGET="Available (${wv:-unknown})"
        SYS_WINGET_BOOL=true
    fi

    # Connectivity
    if command -v curl >/dev/null 2>&1; then
        if curl -fsS --max-time 5 -o /dev/null http://www.msftconnecttest.com/connecttest.txt 2>/dev/null; then
            SYS_ONLINE='Connected'; SYS_ONLINE_BOOL=true
        fi
    elif command -v ping >/dev/null 2>&1; then
        if ping -c1 -W2 www.msftconnecttest.com >/dev/null 2>&1; then
            SYS_ONLINE='Connected'; SYS_ONLINE_BOOL=true
        fi
    fi

    export SYS_PRODUCT SYS_EDITION SYS_DISPLAYVER SYS_BUILD SYS_BUILDNUM \
           SYS_ARCH SYS_WINGET SYS_WINGET_BOOL SYS_ONLINE SYS_ONLINE_BOOL \
           SYS_IS_LTSC SYS_IS_PRO
}

print_system_info() {
    printf '        OS       : %s %s (Build %s)\n' "$SYS_PRODUCT" "$SYS_DISPLAYVER" "$SYS_BUILD"
    printf '        Edition  : %s%s\n' "$SYS_EDITION" "$([[ "$SYS_IS_LTSC" == "1" ]] && echo ' [LTSC]')"
    printf '        Arch     : %s\n' "$SYS_ARCH"
    printf '        Shell    : %s\n' "$(env_label)"
    printf '        Winget   : %s\n' "$SYS_WINGET"
    printf '        Internet : %s\n' "$SYS_ONLINE"
}

# --- Installed Appx packages (requires PowerShell bridge) ----------------
# Emits one package name per line.
list_appx_packages() {
    [[ -z "$PS_EXE" ]] && return 1
    ps_run 'Get-AppxPackage -AllUsers | ForEach-Object { $_.Name }' | tr -d '\r' | grep -v '^[[:space:]]*$'
}

list_appx_provisioned() {
    [[ -z "$PS_EXE" ]] && return 1
    ps_run 'Get-AppxProvisionedPackage -Online | ForEach-Object { $_.DisplayName }' | tr -d '\r' | grep -v '^[[:space:]]*$'
}

# --- Installed Win32 programs from the uninstall hives -------------------
# Emits: DisplayName<TAB>UninstallString
list_win32_programs() {
    local hive out
    for hive in \
        'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' \
        'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' \
        'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'; do
        out=$(win_tool reg query "$hive" /s /v DisplayName 2>/dev/null | tr -d '\r')
        [[ -z "$out" ]] && continue
        awk '/DisplayName/ { $1=""; $2=""; sub(/^[[:space:]]+/,""); if (length($0)) print }' <<<"$out"
    done | sort -u
}

# --- Services ------------------------------------------------------------
# service_start_mode NAME -> auto|demand|disabled|absent
service_start_mode() {
    local name="$1" out
    out=$(win_tool sc qc "$name" 2>/dev/null | tr -d '\r')
    [[ -z "$out" ]] && { echo absent; return; }
    if grep -qi 'START_TYPE' <<<"$out"; then
        if   grep -qi 'DISABLED'    <<<"$out"; then echo disabled
        elif grep -qi 'DEMAND_START'<<<"$out"; then echo demand
        elif grep -qi 'AUTO_START'  <<<"$out"; then echo auto
        else echo unknown; fi
    else
        echo absent
    fi
}

# --- Scheduled tasks -----------------------------------------------------
# task_exists FULLPATH -> 0 if present
task_exists() {
    win_tool schtasks /query /tn "$1" >/dev/null 2>&1
}

# --- Registry ------------------------------------------------------------
# reg_value_equals 'HIVE\PATH' NAME DATA -> 0 if already set to DATA
reg_value_equals() {
    local path="$1" name="$2" want="$3" out cur
    out=$(win_tool reg query "$path" /v "$name" 2>/dev/null | tr -d '\r')
    [[ -z "$out" ]] && return 1
    cur=$(awk -v n="$name" '$0 ~ n { print $NF; exit }' <<<"$out")
    [[ "$cur" =~ ^0x ]] && cur=$((cur))
    [[ "$cur" == "$want" ]]
}

# --- Optional features ---------------------------------------------------
feature_enabled() {
    local name="$1" out
    out=$(win_tool dism /online /get-featureinfo "/featurename:$name" 2>/dev/null | tr -d '\r')
    grep -qi 'State : Enabled' <<<"$out"
}
