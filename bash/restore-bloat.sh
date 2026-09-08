#!/usr/bin/env bash
#
# restore-bloat.sh - undo changes made by remove-bloat.sh.
#
# Options mirror scripts/Restore-Bloat.ps1:
#   1  roll back with a System Restore Point
#   2  re-import a registry backup
#   3  re-register all built-in Windows apps
#   4  reinstall a specific app
#   5  reinstall OneDrive

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

BACKUP_DIR="$SCRIPT_DIR/../backups"
detect_environment

if [[ "$CAN_DEBLOAT" != "1" ]]; then
    printf '\n  %sNo Windows system reachable from this shell (%s).%s\n\n' \
        "$C_RED" "$(env_label)" "$C_RESET"
    exit 3
fi
if ! is_admin; then
    printf '\n  %sRun this from an elevated shell (Run as administrator).%s\n\n' "$C_RED" "$C_RESET"
    exit 4
fi

printf '\n  %sRESTORE MENU%s\n' "$C_CYAN" "$C_RESET"
printf '   [1] Roll back with a System Restore Point   (undoes everything)\n'
printf '   [2] Re-import a registry backup             (undoes tweaks/services)\n'
printf '   [3] Re-register all built-in Windows apps   (fixes Start/Store/Settings)\n'
printf '   [4] Reinstall a specific app\n'
printf '   [5] Reinstall OneDrive\n'
printf '   [Q] Quit\n'
read -r -p '  Choice: ' choice

case "$choice" in
    1)
        printf '  Launching System Restore...\n'
        ps_run 'Get-ComputerRestorePoint | Sort-Object CreationTime -Descending |
                Select-Object SequenceNumber, Description,
                  @{n="Created";e={$_.ConvertToDateTime($_.CreationTime)}} | Format-Table -AutoSize'
        read -r -p '  SequenceNumber to restore (PC will reboot), or blank to cancel: ' n
        if [[ -n "$n" ]]; then
            ps_run "Restore-Computer -RestorePoint $n"
        else
            printf '  Cancelled.\n'
        fi
        ;;
    2)
        mapfile -t dirs < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
        if (( ${#dirs[@]} == 0 )); then
            printf '  %sNo backups found in %s%s\n' "$C_YEL" "$BACKUP_DIR" "$C_RESET"; exit 0
        fi
        for i in "${!dirs[@]}"; do printf '   %s. %s\n' "$((i+1))" "$(basename "${dirs[$i]}")"; done
        read -r -p '  Backup number: ' sel
        [[ "$sel" =~ ^[0-9]+$ ]] || { printf '  Invalid.\n'; exit 2; }
        d="${dirs[$((sel-1))]}"
        shopt -s nullglob
        for f in "$d"/*.reg; do
            printf '   importing %s\n' "$(basename "$f")"
            win_tool reg import "$(to_win_path "$f")" >/dev/null 2>&1 \
                || printf '   %swarning: failed to import %s%s\n' "$C_YEL" "$(basename "$f")" "$C_RESET"
        done
        shopt -u nullglob
        printf '  %sRegistry restored. Reboot recommended.%s\n' "$C_GREEN" "$C_RESET"
        ;;
    3)
        printf '  Re-registering all built-in apps (this takes a minute)...\n'
        ps_run 'Get-AppxPackage -AllUsers | ForEach-Object {
                  try { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop } catch {}
                }'
        printf '  %sDone. Reboot and check Start Menu / Store / Settings.%s\n' "$C_GREEN" "$C_RESET"
        ;;
    4)
        read -r -p '  App name or winget ID (e.g. 9WZDNCRFJBMP for the Store): ' app
        [[ -z "$app" ]] && { printf '  Cancelled.\n'; exit 0; }
        if command -v winget.exe >/dev/null 2>&1; then
            winget.exe install --id "$app" --source msstore \
                --accept-package-agreements --accept-source-agreements
        else
            printf '  %sWinget unavailable. Open the Microsoft Store and search for: %s%s\n' \
                "$C_YEL" "$app" "$C_RESET"
        fi
        ;;
    5)
        ps_run '$s = @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe","$env:SystemRoot\System32\OneDriveSetup.exe") |
                Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($s) { Start-Process $s } else { Start-Process "https://www.microsoft.com/microsoft-365/onedrive/download" }'
        printf '  %sOneDrive setup launched.%s\n' "$C_GREEN" "$C_RESET"
        ;;
    *) printf '  Cancelled.\n' ;;
esac
