#!/usr/bin/env bash
#
# scan-bloat.sh - read-only inventory. Changes nothing, ever.
#
# Usage:
#   ./scan-bloat.sh              scan this Windows system
#   ./scan-bloat.sh --offline    print the catalog only (works on any OS)
#   ./scan-bloat.sh --csv out.csv
#   ./scan-bloat.sh --json out.json

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/bloatdata.sh
source "$SCRIPT_DIR/lib/bloatdata.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"

OFFLINE=0; OUT_CSV=''; OUT_JSON=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline) OFFLINE=1 ;;
        --csv)     OUT_CSV="${2:-}"; shift ;;
        --csv=*)   OUT_CSV="${1#*=}" ;;
        --json)    OUT_JSON="${2:-}"; shift ;;
        --json=*)  OUT_JSON="${1#*=}" ;;
        -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

detect_environment

if [[ "$CAN_DEBLOAT" != "1" && "$OFFLINE" != "1" ]]; then
    printf '\n  %sNo Windows system reachable from this shell.%s\n\n' "$C_YEL" "$C_RESET"
    printf '  Detected environment: %s\n\n' "$(env_label)"
    printf '  Falling back to catalog listing (--offline).\n'
    OFFLINE=1
fi

printf '\n'
if [[ "$OFFLINE" == "1" ]]; then
    printf '  %sCATALOG LISTING (offline - nothing was scanned)%s\n' "$C_CYAN" "$C_RESET"
    printf '  Environment: %s\n\n' "$(env_label)"
else
    get_system_info
    printf '  %s%s %s | Build %s | %s | Winget: %s%s\n\n' \
        "$C_CYAN" "$SYS_PRODUCT" "$SYS_DISPLAYVER" "$SYS_BUILD" "$SYS_ARCH" "$SYS_WINGET" "$C_RESET"
    INSTALLED_APPX="$(list_appx_packages 2>/dev/null || true)"
    INSTALLED_WIN32="$(list_win32_programs 2>/dev/null || true)"
fi

total=0; safe=0; review=0; danger=0
rows=()

for ck in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
    header_shown=0
    for line in "${BLOAT_CATALOG[@]}"; do
        [[ "$(catalog_field "$line" 1)" == "$ck" ]] || continue
        name=$(catalog_field "$line" 2)
        risk=$(catalog_field "$line" 3)
        typ=$(catalog_field  "$line" 4)
        note=$(catalog_field "$line" 6)

        is_protected "$name" && continue

        show=1
        if [[ "$OFFLINE" != "1" ]]; then
            show=0
            case "$typ" in
                Appx)
                    while IFS= read -r p; do
                        [[ -z "$p" ]] && continue
                        # shellcheck disable=SC2053
                        if [[ "$p" == $name ]]; then show=1; break; fi
                    done <<<"$INSTALLED_APPX" ;;
                Win32)
                    while IFS= read -r p; do
                        [[ -z "$p" ]] && continue
                        # shellcheck disable=SC2053
                        if [[ "$p" == $name || "$p" == $name* ]]; then
                            is_driver_related "$p" && { risk='DANGER'; note='Driver-related - protected'; }
                            show=1; break
                        fi
                    done <<<"$INSTALLED_WIN32" ;;
                Service)
                    m=$(service_start_mode "$name")
                    [[ "$m" != "absent" && "$m" != "disabled" ]] && show=1 ;;
                Task)    task_exists "$name" && show=1 ;;
                Feature) feature_enabled "$name" && show=1 ;;
                *)       show=1 ;;
            esac
        fi
        (( show )) || continue

        if (( ! header_shown )); then
            printf '  %s[%s] %s%s\n' "$C_WHITE" "$ck" "${CAT_TITLE[$ck]}" "$C_RESET"
            header_shown=1
        fi
        printf '     %s%-6s%s %-52s %s%s%s\n' \
            "$(risk_color "$risk")" "$risk" "$C_RESET" "$name" "$C_GREY" "$typ" "$C_RESET"
        [[ -n "$note" ]] && printf '            %s\n' "$note"

        rows+=("$ck,$name,$risk,$typ")
        total=$((total+1))
        case "$risk" in SAFE) safe=$((safe+1));; REVIEW) review=$((review+1));; DANGER) danger=$((danger+1));; esac
    done
    (( header_shown )) && printf '\n'
done

printf '  %sTotal: %s items  (%sSAFE %s%s, %sREVIEW %s%s, %sDANGER %s%s)%s\n' \
    "$C_CYAN" "$total" "$C_GREEN" "$safe" "$C_RESET" "$C_YEL" "$review" "$C_RESET" \
    "$C_RED" "$danger" "$C_RESET" "$C_RESET"
printf '  %sNothing was changed.%s\n\n' "$C_GREY" "$C_RESET"

if [[ -n "$OUT_CSV" ]]; then
    # Quote every field so names containing commas cannot break the columns
    {
        echo 'Category,Name,Risk,Type'
        for row in "${rows[@]}"; do
            IFS=',' read -r c n r t <<<"$row"
            printf '"%s","%s","%s","%s"\n' \
                "${c//\"/\"\"}" "${n//\"/\"\"}" "${r//\"/\"\"}" "${t//\"/\"\"}"
        done
    } > "$OUT_CSV"
    printf '  CSV : %s\n' "$OUT_CSV"
fi
if [[ -n "$OUT_JSON" ]]; then
    {
        echo '['
        for i in "${!rows[@]}"; do
            IFS=',' read -r c n r t <<<"${rows[$i]}"
            # Names contain Windows backslashes - must be escaped for valid JSON
            printf '  {"category":"%s","name":"%s","risk":"%s","type":"%s"}' \
                "$(_json_escape "$c")" "$(_json_escape "$n")" \
                "$(_json_escape "$r")" "$(_json_escape "$t")"
            [[ $i -lt $(( ${#rows[@]} - 1 )) ]] && printf ','
            printf '\n'
        done
        echo ']'
    } > "$OUT_JSON"
    printf '  JSON: %s\n' "$OUT_JSON"
fi
