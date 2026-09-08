#!/usr/bin/env bash
#
# remove-bloat.sh - Windows 11 bloatware removal, bash edition.
#
# Bash counterpart to scripts/Remove-Bloat.ps1. Same catalog, same protected
# list, same safety model. Requires a Windows system reachable from this
# shell (Git Bash, MSYS2, Cygwin or WSL with interop enabled).
#
# Usage:
#   ./remove-bloat.sh                    interactive
#   ./remove-bloat.sh --dry-run          show actions, change nothing
#   ./remove-bloat.sh --safe-only --yes  remove all SAFE items, no prompts
#   ./remove-bloat.sh --categories 1,2,5
#
# Options:
#   -n, --dry-run              never modify anything
#   -y, --yes                  skip confirmation prompts
#   -s, --safe-only            only act on SAFE items
#   -c, --categories LIST      comma-separated category numbers
#       --skip-restore-point   do not create a restore point (NOT advised)
#       --log PATH             custom log file
#   -h, --help                 this help

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/bloatdata.sh
source "$SCRIPT_DIR/lib/bloatdata.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/remove.sh
source "$SCRIPT_DIR/lib/remove.sh"

OPT_YES=0; OPT_SAFE_ONLY=0; OPT_CATEGORIES=''
OPT_SKIP_RP=0; OPT_LOG=''

usage() { sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)          DRY_RUN=1 ;;
        -y|--yes)              OPT_YES=1 ;;
        -s|--safe-only)        OPT_SAFE_ONLY=1 ;;
        -c|--categories)       OPT_CATEGORIES="${2:-}"; shift ;;
        --categories=*)        OPT_CATEGORIES="${1#*=}" ;;
        --skip-restore-point)  OPT_SKIP_RP=1 ;;
        --log)                 OPT_LOG="${2:-}"; shift ;;
        --log=*)               OPT_LOG="${1#*=}" ;;
        -h|--help)             usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
    esac
    shift
done

banner() {
    printf '\n'
    printf '  %s===============================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '  %s  WINDOWS 11 BLOATWARE REMOVAL - bash edition%s\n' "$C_CYAN" "$C_RESET"
    printf '  %s  Safe  |  Reversible  |  Logged%s\n' "$C_GREY" "$C_RESET"
    printf '  %s===============================================================%s\n' "$C_CYAN" "$C_RESET"
    printf '\n'
}

banner
detect_environment

# --- Refuse to pretend on a non-Windows host ----------------------------
if [[ "$CAN_DEBLOAT" != "1" ]]; then
    printf '  %sThis script cannot run here.%s\n\n' "$C_RED" "$C_RESET"
    printf '  Detected environment : %s\n' "$(env_label)"
    printf '  Windows reachable    : no\n\n'
    printf '  Debloating requires a Windows system. Windows package, service and\n'
    printf '  registry APIs simply do not exist on %s, and no shell can\n' "$(env_label)"
    printf '  emulate them.\n\n'
    printf '  %sWhere this script DOES work:%s\n' "$C_WHITE" "$C_RESET"
    printf '    * Git Bash / MSYS2 on Windows\n'
    printf '    * Cygwin on Windows\n'
    printf '    * WSL, with Windows interop enabled (the default)\n\n'
    printf '  On native Linux or macOS there is no Windows to clean.\n'
    printf '  To inspect the catalog without a Windows host, run:\n'
    printf '    %s./scan-bloat.sh --offline%s\n\n' "$C_CYAN" "$C_RESET"
    exit 3
fi

# --- Step 1: admin -------------------------------------------------------
if ! is_admin; then
    printf '  %sAdministrator rights are required.%s\n\n' "$C_YEL" "$C_RESET"
    printf '  Please do this:\n'
    case "$DEBLOAT_ENV" in
        wsl) printf '    1. Close this shell\n'
             printf '    2. Right-click Windows Terminal > Run as administrator\n'
             printf '    3. Start WSL there and re-run this script\n' ;;
        *)   printf '    1. Close Git Bash\n'
             printf '    2. Right-click the Git Bash icon > Run as administrator\n'
             printf '    3. Re-run this script\n' ;;
    esac
    printf '\n'
    exit 4
fi

# --- Step 2: detect ------------------------------------------------------
printf '  %s[1/6] Detecting system...%s\n' "$C_CYAN" "$C_RESET"
get_system_info

if [[ -z "$OPT_LOG" ]]; then
    OPT_LOG="$SCRIPT_DIR/../logs/BloatRemoval-$(date '+%Y-%m-%d-%H%M%S').log"
fi
log_init "$OPT_LOG"
print_system_info
printf '        Log      : %s\n' "$OPT_LOG"

if (( SYS_BUILDNUM > 0 && SYS_BUILDNUM < 22000 )); then
    printf '  %sWARNING: this does not look like Windows 11 (build %s).%s\n' "$C_YEL" "$SYS_BUILDNUM" "$C_RESET"
    if [[ "$OPT_YES" != "1" ]]; then
        read -r -p '  Continue anyway? (y/N) ' a
        [[ "$a" == "y" ]] || exit 0
    fi
fi

# --- Step 3: scan --------------------------------------------------------
printf '\n  %s[2/6] Scanning (protected packages excluded)...%s\n' "$C_CYAN" "$C_RESET"

INSTALLED_APPX="$(list_appx_packages 2>/dev/null || true)"
INSTALLED_WIN32="$(list_win32_programs 2>/dev/null || true)"

FOUND=()   # CATKEY|NAME|RISK|TYPE|EXTRA|NOTE
for line in "${BLOAT_CATALOG[@]}"; do
    ckey=$(catalog_field "$line" 1)
    name=$(catalog_field "$line" 2)
    risk=$(catalog_field "$line" 3)
    typ=$(catalog_field  "$line" 4)
    extra=$(catalog_field "$line" 5)
    note=$(catalog_field "$line" 6)

    is_protected "$name" && continue

    present=0
    case "$typ" in
        Appx)
            # shell glob match against the installed list
            while IFS= read -r p; do
                [[ -z "$p" ]] && continue
                # shellcheck disable=SC2053
                if [[ "$p" == $name ]]; then present=1; break; fi
            done <<<"$INSTALLED_APPX"
            ;;
        Win32)
            while IFS= read -r p; do
                [[ -z "$p" ]] && continue
                # shellcheck disable=SC2053
                if [[ "$p" == $name || "$p" == $name* ]]; then
                    if is_driver_related "$p"; then risk='DANGER'; note='Driver-related - may break hardware'; fi
                    present=1; break
                fi
            done <<<"$INSTALLED_WIN32"
            ;;
        Service)
            mode=$(service_start_mode "$name")
            [[ "$mode" != "absent" && "$mode" != "$extra" && "$mode" != "disabled" ]] && present=1
            ;;
        Task)      task_exists "$name" && present=1 ;;
        Registry)
            rpath="${extra%%::*}"; rname="${extra#*::}"; rname="${rname%%::*}"; rdata="${extra##*::}"
            reg_value_equals "$rpath" "$rname" "$rdata" || present=1
            ;;
        Feature)   feature_enabled "$name" && present=1 ;;
        Startup|Cleanup|OneDrive|Shortcut) present=1 ;;
    esac

    (( present )) && FOUND+=("$ckey|$name|$risk|$typ|$extra|$note")
done

if (( ${#FOUND[@]} == 0 )); then
    printf '  %sNothing found - your system already looks clean.%s\n' "$C_GREEN" "$C_RESET"
    log_complete 0 0 0 'null'
    exit 0
fi
printf '        Found %s candidate item(s).\n' "${#FOUND[@]}"

# --- Steps 4/5: display --------------------------------------------------
printf '\n  %s[3/6] Findings%s\n' "$C_CYAN" "$C_RESET"
for ck in $(printf '%s\n' "${FOUND[@]}" | cut -d'|' -f1 | sort -un); do
    printf '\n  %s[%s] %s%s\n' "$C_WHITE" "$ck" "${CAT_TITLE[$ck]}" "$C_RESET"
    for f in "${FOUND[@]}"; do
        [[ "$(catalog_field "$f" 1)" == "$ck" ]] || continue
        n=$(catalog_field "$f" 2); r=$(catalog_field "$f" 3)
        t=$(catalog_field "$f" 4); nt=$(catalog_field "$f" 6)
        printf '       %s%-6s%s %s %s[%s]%s\n' "$(risk_color "$r")" "$r" "$C_RESET" "$n" "$C_GREY" "$t" "$C_RESET"
        [[ -n "$nt" ]] && printf '              note: %s\n' "$nt"
    done
done

# --- Step 6: menu --------------------------------------------------------
SELECTED=()
if [[ -n "$OPT_CATEGORIES" ]]; then
    IFS=',' read -ra want <<<"$OPT_CATEGORIES"
    for f in "${FOUND[@]}"; do
        for w in "${want[@]}"; do
            [[ "$(catalog_field "$f" 1)" == "${w// /}" ]] && SELECTED+=("$f")
        done
    done
elif [[ "$OPT_YES" == "1" && "$OPT_SAFE_ONLY" == "1" ]]; then
    for f in "${FOUND[@]}"; do
        [[ "$(catalog_field "$f" 3)" == "SAFE" ]] && SELECTED+=("$f")
    done
else
    while true; do
        printf '\n  %s---------------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        printf '   [1-13] Choose categories (comma separated, e.g. 1,2,5)\n'
        printf '   %s[A]    Remove all SAFE items only  (recommended)%s\n' "$C_GREEN" "$C_RESET"
        printf '   [S]    Scan only - write report and exit\n'
        printf '   [Q]    Quit without changes\n'
        printf '  %s---------------------------------------------------------------%s\n' "$C_CYAN" "$C_RESET"
        read -r -p '  Your choice: ' choice
        case "$choice" in
            [Qq]) printf '  Cancelled. Nothing changed.\n'; exit 0 ;;
            [Ss]) log_msg INFO "Scan-only mode. ${#FOUND[@]} items found."
                  log_complete 0 0 0 'null'
                  printf '  Report saved to %s\n' "$LOG_FILE"; exit 0 ;;
            [Aa]) for f in "${FOUND[@]}"; do
                      [[ "$(catalog_field "$f" 3)" == "SAFE" ]] && SELECTED+=("$f")
                  done; break ;;
            *)
                IFS=',' read -ra want <<<"$choice"
                for f in "${FOUND[@]}"; do
                    for w in "${want[@]}"; do
                        [[ "$(catalog_field "$f" 1)" == "${w// /}" ]] && SELECTED+=("$f")
                    done
                done
                (( ${#SELECTED[@]} )) && break
                printf '  %sInvalid choice, try again.%s\n' "$C_YEL" "$C_RESET" ;;
        esac
    done
fi

if [[ "$OPT_SAFE_ONLY" == "1" ]]; then
    tmp=(); for f in "${SELECTED[@]}"; do
        [[ "$(catalog_field "$f" 3)" == "SAFE" ]] && tmp+=("$f")
    done; SELECTED=("${tmp[@]}")
fi
if (( ${#SELECTED[@]} == 0 )); then
    printf '  Nothing selected. Exiting.\n'; exit 0
fi

# Gaming question
has_gaming=0
for f in "${SELECTED[@]}"; do [[ "$(catalog_field "$f" 1)" == "11" ]] && has_gaming=1; done
if (( has_gaming )) && [[ "$OPT_YES" != "1" ]]; then
    read -r -p '  Do you play games or use Xbox / Game Pass? (y/N) ' g
    if [[ "$g" == "y" ]]; then
        printf '  %sSkipping Xbox/Gaming items.%s\n' "$C_YEL" "$C_RESET"
        tmp=(); for f in "${SELECTED[@]}"; do
            [[ "$(catalog_field "$f" 1)" != "11" ]] && tmp+=("$f")
        done; SELECTED=("${tmp[@]}")
    fi
fi

# --- Step 7: dry run -----------------------------------------------------
printf '\n  %s[4/6] DRY RUN - these actions would run:%s\n' "$C_CYAN" "$C_RESET"
for f in "${SELECTED[@]}"; do
    n=$(catalog_field "$f" 2); r=$(catalog_field "$f" 3); t=$(catalog_field "$f" 4)
    printf '       %s%-6s%s %s  ->  %s\n' "$(risk_color "$r")" "$r" "$C_RESET" "$n" "$t"
done
printf '\n        %s item(s) selected\n' "${#SELECTED[@]}"

if [[ "$DRY_RUN" == "1" ]]; then
    printf '  %s--dry-run specified. No changes made.%s\n' "$C_YEL" "$C_RESET"
    log_complete 0 0 0 'null'
    exit 0
fi

# --- Step 8: confirm -----------------------------------------------------
if [[ "$OPT_YES" != "1" ]]; then
    danger=(); for f in "${SELECTED[@]}"; do
        [[ "$(catalog_field "$f" 3)" == "DANGER" ]] && danger+=("$f")
    done
    if (( ${#danger[@]} )); then
        printf '\n  %sWARNING: %s DANGER item(s) selected. These can break hardware.%s\n' \
               "$C_RED" "${#danger[@]}" "$C_RESET"
        read -r -p '  Type exactly "I ACCEPT" to include them, anything else skips: ' d
        if [[ "$d" != "I ACCEPT" ]]; then
            tmp=(); for f in "${SELECTED[@]}"; do
                [[ "$(catalog_field "$f" 3)" != "DANGER" ]] && tmp+=("$f")
            done; SELECTED=("${tmp[@]}")
            printf '  %sDANGER items skipped.%s\n' "$C_YEL" "$C_RESET"
        fi
    fi
    printf '\n'
    read -r -p '  Proceed with removal? (y/N) ' ok
    [[ "$ok" == "y" ]] || { printf '  Cancelled. Nothing changed.\n'; exit 0; }
fi

# --- Step 9: backup ------------------------------------------------------
printf '\n  %s[5/6] Creating safety net...%s\n' "$C_CYAN" "$C_RESET"
if [[ "$OPT_SKIP_RP" != "1" ]]; then
    if ! create_restore_point && [[ "$OPT_YES" != "1" ]]; then
        read -r -p '  Restore point failed. Continue anyway? (y/N) ' c
        [[ "$c" == "y" ]] || exit 1
    fi
else
    log_msg WARN 'System Restore Point: SKIPPED by user'
fi
BK=$(backup_registry "$SCRIPT_DIR/../backups")
log_msg SUCCESS "Registry Backup: SAVED -> $BK"

# --- Step 10: execute ----------------------------------------------------
printf '\n  %s[6/6] Removing...%s\n' "$C_CYAN" "$C_RESET"
removed=0; failed=0; skipped=0; av_removed=0
for ck in $(printf '%s\n' "${SELECTED[@]}" | cut -d'|' -f1 | sort -un); do
    log_msg HEADER "CATEGORY $ck: ${CAT_TITLE[$ck]}"
    for f in "${SELECTED[@]}"; do
        [[ "$(catalog_field "$f" 1)" == "$ck" ]] || continue
        res=$(remove_item "$ck" "$(catalog_field "$f" 2)" "$(catalog_field "$f" 3)" \
                          "$(catalog_field "$f" 4)" "$(catalog_field "$f" 5)")
        case "$res" in
            success) removed=$((removed+1)); [[ "$ck" == "4" ]] && av_removed=1 ;;
            failed)  failed=$((failed+1)) ;;
            *)       skipped=$((skipped+1)) ;;
        esac
    done
done

# --- Step 11: Defender handoff -------------------------------------------
if (( av_removed )); then
    enable_defender || true
    REBOOT_REQUIRED=1
fi

# --- Step 12: validate ---------------------------------------------------
VALIDATION=$(validate_system)

# --- Step 13: summary ----------------------------------------------------
printf '\n  Removed: %s   Skipped: %s   Failed: %s\n' "$removed" "$skipped" "$failed"
log_complete "$removed" 0 "$REBOOT_REQUIRED" "$VALIDATION"
printf '  Log : %s\n' "$LOG_FILE"
printf '  JSON: %s\n' "$JSON_FILE"
printf '  Registry backup: %s\n' "$BK"
printf '\n  To restore anything: %s./restore-bloat.sh%s\n' "$C_CYAN" "$C_RESET"
[[ "$REBOOT_REQUIRED" == "1" ]] && printf '  %s>>> REBOOT RECOMMENDED <<<%s\n' "$C_YEL" "$C_RESET"
printf '\n'
