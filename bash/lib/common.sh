#!/usr/bin/env bash
# common.sh - environment detection, logging, helpers.
# Sourced by every bash entry point. Requires bash 4+.

set -o pipefail

# --- Colours (disabled when not a TTY or NO_COLOR is set) ---------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'; C_RED=$'\033[31m';  C_GREEN=$'\033[32m'
    C_YEL=$'\033[33m';  C_CYAN=$'\033[36m'; C_GREY=$'\033[90m'
    C_WHITE=$'\033[97m'; C_BOLD=$'\033[1m'
else
    C_RESET=''; C_RED=''; C_GREEN=''; C_YEL=''
    C_CYAN=''; C_GREY=''; C_WHITE=''; C_BOLD=''
fi
export C_RESET C_RED C_GREEN C_YEL C_CYAN C_GREY C_WHITE C_BOLD

risk_color() {
    case "$1" in
        SAFE)   printf '%s' "$C_GREEN" ;;
        REVIEW) printf '%s' "$C_YEL" ;;
        DANGER) printf '%s' "$C_RED" ;;
        *)      printf '%s' "$C_GREY" ;;
    esac
}

# --- Environment detection ----------------------------------------------
# Sets: DEBLOAT_ENV  msys | cygwin | wsl | linux | macos | unknown
#       PS_EXE       path to powershell.exe / pwsh.exe ('' if none)
#       CAN_DEBLOAT  1 if a Windows system is reachable, else 0
detect_environment() {
    DEBLOAT_ENV='unknown'
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*)  DEBLOAT_ENV='msys'   ;;
        CYGWIN*)       DEBLOAT_ENV='cygwin' ;;
        Darwin)        DEBLOAT_ENV='macos'  ;;
        Linux)
            if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
                DEBLOAT_ENV='wsl'
            else
                DEBLOAT_ENV='linux'
            fi
            ;;
    esac

    PS_EXE=''
    local c
    for c in powershell.exe pwsh.exe; do
        if command -v "$c" >/dev/null 2>&1; then PS_EXE="$c"; break; fi
    done
    if [[ -z "$PS_EXE" ]]; then
        for c in \
            "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
            "/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" \
            "/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"; do
            if [[ -x "$c" ]]; then PS_EXE="$c"; break; fi
        done
    fi

    CAN_DEBLOAT=0
    [[ -n "$PS_EXE" ]] && CAN_DEBLOAT=1
    export DEBLOAT_ENV PS_EXE CAN_DEBLOAT
}

env_label() {
    case "$DEBLOAT_ENV" in
        msys)   echo "Git Bash / MSYS2 on Windows" ;;
        cygwin) echo "Cygwin on Windows" ;;
        wsl)    echo "WSL (${WSL_DISTRO_NAME:-unknown distro})" ;;
        linux)  echo "native Linux" ;;
        macos)  echo "macOS" ;;
        *)      echo "unknown" ;;
    esac
}

# --- PowerShell bridge ---------------------------------------------------
# Appx and CIM work has no native Windows CLI equivalent, so it is
# delegated to powershell.exe. Everything else uses reg/sc/schtasks/dism.
ps_run() {
    if [[ -z "$PS_EXE" ]]; then
        echo "ERROR: PowerShell not reachable from this shell" >&2
        return 127
    fi
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
        "$PS_EXE" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$1" 2>&1
}

# Windows tool wrapper (on PATH under MSYS/Cygwin; needs full path on WSL)
win_tool() {
    local t="$1"; shift
    if command -v "${t}.exe" >/dev/null 2>&1; then
        MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "${t}.exe" "$@"
    elif [[ -x "/mnt/c/Windows/System32/${t}.exe" ]]; then
        "/mnt/c/Windows/System32/${t}.exe" "$@"
    else
        return 127
    fi
}

# --- Admin check ---------------------------------------------------------
is_admin() {
    if win_tool net session >/dev/null 2>&1; then return 0; fi
    if [[ -n "$PS_EXE" ]]; then
        local r
        r=$(ps_run '([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' | tr -d '[:space:]')
        [[ "$r" == "True" ]] && return 0
    fi
    return 1
}

# --- Path translation ----------------------------------------------------
to_win_path() {
    case "$DEBLOAT_ENV" in
        msys|cygwin) cygpath -w "$1" 2>/dev/null || echo "$1" ;;
        wsl)         wslpath -w "$1" 2>/dev/null || echo "$1" ;;
        *)           echo "$1" ;;
    esac
}

# --- Logging (mirrors Write-RemovalLog.ps1: .log + .json) ----------------
LOG_FILE=''; JSON_FILE=''; JSON_ACTIONS=''

log_init() {
    local path="$1"
    LOG_FILE="$path"
    JSON_FILE="${path%.log}.json"
    JSON_ACTIONS=''
    mkdir -p "$(dirname "$LOG_FILE")"
    {
        echo "==============================================================="
        echo "  Bloatware Removal Log (bash)"
        echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Shell env: $(env_label)"
        echo "  Windows: ${SYS_PRODUCT:-unknown} ${SYS_DISPLAYVER:-} (Build ${SYS_BUILD:-?})"
        echo "  Architecture: ${SYS_ARCH:-unknown}"
        echo "  Winget: ${SYS_WINGET:-unknown}"
        echo "  Internet: ${SYS_ONLINE:-unknown}"
        echo "==============================================================="
        echo
    } > "$LOG_FILE"
}

_json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g'; }

log_msg() {
    local level="$1" msg="$2" pkg="${3:-}" cat="${4:-}" method="${5:-}"
    local ts line color
    ts=$(date '+%H:%M:%S')
    if [[ "$level" == "HEADER" ]]; then
        line=$'\n'"-- ${msg} --"
    else
        line="[$ts] $msg"
    fi
    [[ -n "$LOG_FILE" ]] && printf '%s\n' "$line" >> "$LOG_FILE"
    case "$level" in
        SUCCESS) color="$C_GREEN" ;; WARN) color="$C_YEL" ;;
        FAIL)    color="$C_RED"   ;; SKIP) color="$C_GREY" ;;
        HEADER)  color="$C_CYAN"  ;; *)    color='' ;;
    esac
    if [[ "${QUIET:-0}" != "1" ]]; then
        printf '%s%s%s\n' "$color" "$line" "$C_RESET"
    fi
    if [[ -n "$pkg" ]]; then
        local lvl
        lvl=$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')
        [[ -n "$JSON_ACTIONS" ]] && JSON_ACTIONS+=","
        JSON_ACTIONS+=$(printf '\n    {"timestamp":"%s","category":"%s","package":"%s","method":"%s","result":"%s","details":"%s"}' \
            "$(date '+%Y-%m-%dT%H:%M:%S')" "$(_json_escape "$cat")" "$(_json_escape "$pkg")" \
            "$(_json_escape "$method")" "$lvl" "$(_json_escape "$msg")")
    fi
}

log_complete() {
    local removed="$1" freed="$2" reboot="$3" validation_json="${4:-null}"
    local gb reboot_word reboot_bool
    gb=$(awk -v b="$freed" 'BEGIN{printf "%.2f", b/1073741824}')
    if [[ "$reboot" == "1" ]]; then reboot_word=YES; reboot_bool=true
    else reboot_word=NO; reboot_bool=false; fi
    {
        echo
        echo "==============================================================="
        echo "  SUMMARY"
        echo "  Items removed: $removed"
        echo "  Estimated space freed: ~${gb} GB"
        echo "  Reboot recommended: $reboot_word"
        echo "==============================================================="
    } | tee -a "$LOG_FILE"

    {
        echo "{"
        echo "  \"timestamp\": \"$(date '+%Y-%m-%dT%H:%M:%S')\","
        echo "  \"generator\": \"bash\","
        echo "  \"system\": {"
        echo "    \"shellEnv\": \"${DEBLOAT_ENV}\","
        echo "    \"os\": \"$(_json_escape "${SYS_PRODUCT:-}")\","
        echo "    \"build\": \"$(_json_escape "${SYS_DISPLAYVER:-}")\","
        echo "    \"version\": \"$(_json_escape "${SYS_BUILD:-}")\","
        echo "    \"arch\": \"$(_json_escape "${SYS_ARCH:-}")\","
        echo "    \"winget\": ${SYS_WINGET_BOOL:-false},"
        echo "    \"internet\": ${SYS_ONLINE_BOOL:-false}"
        echo "  },"
        echo "  \"actions\": [${JSON_ACTIONS}"
        echo "  ],"
        echo "  \"validation\": ${validation_json},"
        echo "  \"summary\": {"
        echo "    \"itemsRemoved\": ${removed},"
        echo "    \"spaceFreedBytes\": ${freed},"
        echo "    \"rebootRequired\": ${reboot_bool}"
        echo "  }"
        echo "}"
    } > "$JSON_FILE"
}
