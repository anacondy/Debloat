#!/usr/bin/env bash
#
# test_bloat.sh - self-contained test suite for the bash edition.
# Runs on ANY OS (no Windows needed). Exercises the pure-logic layer and
# uses a mock Windows toolchain to test the removal engine end to end.
#
#   ./tests/test_bloat.sh          run all tests
#   ./tests/test_bloat.sh -v       verbose

set -uo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$TEST_DIR/.." && pwd)"
REPO="$(cd -- "$ROOT/.." && pwd)"
VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

PASS=0; FAIL=0; FAILED_NAMES=()

TC_G=$'\033[32m'; TC_R=$'\033[31m'; TC_Y=$'\033[33m'; TC_C=$'\033[36m'; TC_N=$'\033[0m'

ok()   { PASS=$((PASS+1)); [[ "$VERBOSE" == "1" ]] && printf '  %sPASS%s %s\n' "$TC_G" "$TC_N" "$1"; return 0; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf '  %sFAIL%s %s\n' "$TC_R" "$TC_N" "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; return 0; }

assert_true()  { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1" "expected success: $2"; fi; }
assert_false() { if eval "$2" >/dev/null 2>&1; then bad "$1" "expected failure: $2"; else ok "$1"; fi; }
assert_eq()    { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1" "expected '$3' got '$2'"; fi; }
assert_contains() { if [[ "$2" == *"$3"* ]]; then ok "$1"; else bad "$1" "expected to contain '$3' in: $2"; fi; }

section() { printf '\n%s== %s ==%s\n' "$TC_C" "$1" "$TC_N"; }

# =====================================================================
section "1. Library loading"
# =====================================================================
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"    && ok "common.sh sources"    || bad "common.sh sources"
# shellcheck source=../lib/bloatdata.sh
source "$ROOT/lib/bloatdata.sh" && ok "bloatdata.sh sources" || bad "bloatdata.sh sources"
# shellcheck source=../lib/detect.sh
source "$ROOT/lib/detect.sh"    && ok "detect.sh sources"    || bad "detect.sh sources"
# shellcheck source=../lib/remove.sh
source "$ROOT/lib/remove.sh"    && ok "remove.sh sources"    || bad "remove.sh sources"

# =====================================================================
section "2. Protected list - MUST refuse (safety critical)"
# =====================================================================
MUST_PROTECT=(
    'Microsoft.WindowsStore'
    'Microsoft.WindowsStore_8wekyb3d8bbwe'
    'Microsoft.DesktopAppInstaller'
    'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
    'Microsoft.VCLibs.140.00'
    'Microsoft.VCLibs.140.00.UWPDesktop'
    'Microsoft.UI.Xaml.2.8'
    'Microsoft.NET.Native.Runtime.2.2'
    'Microsoft.NET.Native.Framework.2.2'
    'Microsoft.SecHealthUI'
    'Windows.immersivecontrolpanel'
    'windows.immersivecontrolpanel'
    'Microsoft.LanguageExperiencePackfr-FR'
    'Microsoft.LanguageExperiencePackde-DE'
    'Microsoft.WindowsAppRuntime.1.5'
    'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.Windows.ShellExperienceHost'
    'Microsoft.Windows.CloudExperienceHost'
    'Microsoft.Windows.NarratorShell'
    'Microsoft.AAD.BrokerPlugin'
    'Microsoft.AccountsControl'
    'Microsoft.CredDialogHost'
    'Microsoft.LockApp'
    'Microsoft.Windows.Search'
    'Microsoft.WindowsCalculator'
    'Microsoft.Paint'
    'Microsoft.ScreenSketch'
    'Microsoft.WindowsTerminal'
    'Microsoft.Windows.Photos'
    'Microsoft.Windows.CbsPreview'
    'Microsoft.Services.Store.Engagement'
    'Microsoft.StorePurchaseApp'
    'Microsoft.WindowsNotepad'
)
for p in "${MUST_PROTECT[@]}"; do
    assert_true "protected: $p" "is_protected '$p'"
done

# =====================================================================
section "3. Protected list - MUST NOT over-block"
# =====================================================================
MUST_NOT_BLOCK=(
    'king.com.CandyCrushSaga'
    'Microsoft.Copilot'
    'MicrosoftTeams'
    'MSTeams'
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.YourPhone'
    'SpotifyAB.SpotifyMusic'
    'BytedancePte.Ltd.TikTok'
    'Microsoft.549981C3F5F10'
    'MicrosoftWindows.Client.WebExperience'
    'Microsoft.SkypeApp'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.Windows.DevHome'
    'Microsoft.PowerAutomateDesktop'
)
for p in "${MUST_NOT_BLOCK[@]}"; do
    assert_false "removable: $p" "is_protected '$p'"
done

# =====================================================================
section "4. Case-insensitivity of the guard"
# =====================================================================
assert_true  "lowercase store protected"  "is_protected 'microsoft.windowsstore'"
assert_true  "uppercase store protected"  "is_protected 'MICROSOFT.WINDOWSSTORE'"
assert_true  "mixed vclibs protected"     "is_protected 'MiCrOsOfT.vClIbS.140.00'"
assert_false "lowercase candy removable"  "is_protected 'king.com.candycrushsaga'"

# =====================================================================
section "5. Driver detection"
# =====================================================================
DRIVERS=(
    'Realtek High Definition Audio Driver'
    'Realtek Audio Console'
    'NVIDIA Graphics Driver 551.23'
    'Intel(R) Wireless Bluetooth'
    'Synaptics Precision Touchpad Driver'
    'Dolby Audio Premium'
    'Nahimic 3'
    'AMD Software: Adrenalin Edition'
    'Intel(R) Management Engine Components'
    'Goodix Fingerprint Driver'
    'Thunderbolt(TM) Software'
    'Waves MaxxAudio Pro for Dell'
    'ELAN Touchpad'
    'Conexant SmartAudio'
    'Qualcomm Atheros Bluetooth'
)
for d in "${DRIVERS[@]}"; do
    assert_true "driver: $d" "is_driver_related '$d'"
done

NON_DRIVERS=(
    'Candy Crush Saga'
    'Dell Digital Delivery'
    'McAfee LiveSafe'
    'Spotify'
    'Lenovo Vantage'
    'HP JumpStart'
)
for d in "${NON_DRIVERS[@]}"; do
    assert_false "not driver: $d" "is_driver_related '$d'"
done

# =====================================================================
section "6. Catalog integrity"
# =====================================================================
count=$(catalog_count)
assert_eq "catalog has 185 entries" "$count" "185"
assert_eq "13 category titles" "${#CAT_TITLE[@]}" "13"
assert_eq "27 exact protected" "${#PROTECTED_EXACT[@]}" "27"
assert_eq "17 substring guards" "${#PROTECTED_CONTAINS[@]}" "17"
assert_eq "34 driver keywords" "${#DRIVER_KEYWORDS[@]}" "34"

# Every entry well-formed
malformed=0; bad_risk=0; bad_type=0; bad_cat=0
VALID_TYPES='Appx Win32 Service Task Startup Registry Feature Cleanup OneDrive Shortcut'
for line in "${BLOAT_CATALOG[@]}"; do
    n=$(awk -F'|' '{print NF}' <<<"$line")
    [[ "$n" -eq 6 ]] || { malformed=$((malformed+1)); [[ "$VERBOSE" == 1 ]] && echo "  malformed($n): $line"; }
    r=$(catalog_field "$line" 3)
    case "$r" in SAFE|REVIEW|DANGER) ;; *) bad_risk=$((bad_risk+1));; esac
    t=$(catalog_field "$line" 4)
    [[ " $VALID_TYPES " == *" $t "* ]] || bad_type=$((bad_type+1))
    c=$(catalog_field "$line" 1)
    [[ -n "${CAT_TITLE[$c]:-}" ]] || bad_cat=$((bad_cat+1))
done
assert_eq "all entries have 6 fields" "$malformed" "0"
assert_eq "all risks valid"           "$bad_risk"  "0"
assert_eq "all types valid"           "$bad_type"  "0"
assert_eq "all categories known"      "$bad_cat"   "0"

# No catalog entry may target a protected package
leak=0
for line in "${BLOAT_CATALOG[@]}"; do
    n=$(catalog_field "$line" 2)
    is_protected "$n" && { leak=$((leak+1)); printf '        LEAK: %s\n' "$n"; }
done
assert_eq "no catalog entry is protected" "$leak" "0"

# Registry entries must be well-formed HIVE\PATH::NAME::DATA
badreg=0
for line in "${BLOAT_CATALOG[@]}"; do
    [[ "$(catalog_field "$line" 4)" == "Registry" ]] || continue
    e=$(catalog_field "$line" 5)
    [[ "$e" == *"::"*"::"* ]] || { badreg=$((badreg+1)); printf '        BADREG: %s\n' "$line"; }
    d="${e##*::}"
    [[ "$d" =~ ^[0-9]+$ ]] || { badreg=$((badreg+1)); printf '        BADDATA: %s\n' "$line"; }
done
assert_eq "registry entries well-formed" "$badreg" "0"

# Service entries must declare a valid sc.exe start mode
badsvc=0
for line in "${BLOAT_CATALOG[@]}"; do
    [[ "$(catalog_field "$line" 4)" == "Service" ]] || continue
    m=$(catalog_field "$line" 5)
    case "$m" in auto|demand|disabled) ;; *) badsvc=$((badsvc+1)); printf '        BADSVC: %s\n' "$line";; esac
done
assert_eq "service modes valid for sc.exe" "$badsvc" "0"

# =====================================================================
section "7. Parity with the PowerShell catalog"
# =====================================================================
PS_BIN=''
for c in "$HOME/.pwsh/pwsh" pwsh powershell; do
    command -v "$c" >/dev/null 2>&1 && { PS_BIN="$c"; break; }
    [[ -x "$c" ]] && { PS_BIN="$c"; break; }
done

if [[ -n "$PS_BIN" && -f "$REPO/scripts/helpers/BloatData.ps1" ]]; then
    ps_cat=$("$PS_BIN" -NoProfile -Command "
        . '$REPO/scripts/helpers/BloatData.ps1'
        foreach(\$k in \$Global:BloatCatalog.Keys){
          foreach(\$i in \$Global:BloatCatalog[\$k].Items){ \"\$k|\$(\$i.N)\" } }" 2>/dev/null | tr -d '\r' | sort -u)
    sh_cat=$(for l in "${BLOAT_CATALOG[@]}"; do
                printf '%s|%s\n' "$(catalog_field "$l" 1)" "$(catalog_field "$l" 2)"
             done | sort -u)
    only_ps=$(comm -23 <(printf '%s\n' "$ps_cat") <(printf '%s\n' "$sh_cat"))
    only_sh=$(comm -13 <(printf '%s\n' "$ps_cat") <(printf '%s\n' "$sh_cat"))
    assert_eq "catalog matches PowerShell (missing)" "${only_ps:-none}" "none"
    assert_eq "catalog matches PowerShell (extra)"   "${only_sh:-none}" "none"

    ps_prot=$("$PS_BIN" -NoProfile -Command "
        . '$REPO/scripts/helpers/BloatData.ps1'
        \$Global:ProtectedExact -join \"\`n\"" 2>/dev/null | tr -d '\r' | sort -u)
    sh_prot=$(printf '%s\n' "${PROTECTED_EXACT[@]}" | sort -u)
    diff_prot=$(comm -3 <(printf '%s\n' "$ps_prot") <(printf '%s\n' "$sh_prot"))
    assert_eq "protected list matches PowerShell" "${diff_prot:-none}" "none"

    # Cross-implementation behavioural check on the guard itself
    mismatch=0
    for p in "${MUST_PROTECT[@]}" "${MUST_NOT_BLOCK[@]}"; do
        psr=$("$PS_BIN" -NoProfile -Command "
            . '$REPO/scripts/helpers/BloatData.ps1'
            if (Test-Protected '$p') { 'Y' } else { 'N' }" 2>/dev/null | tr -d '\r[:space:]')
        if is_protected "$p"; then shr=Y; else shr=N; fi
        [[ "$psr" == "$shr" ]] || { mismatch=$((mismatch+1)); printf '        MISMATCH %s: ps=%s bash=%s\n' "$p" "$psr" "$shr"; }
    done
    assert_eq "guard agrees with PowerShell on all probes" "$mismatch" "0"
else
    printf '  %sSKIP%s parity tests (no PowerShell available)\n' "$TC_Y" "$TC_N"
fi

# =====================================================================
section "8. Environment detection"
# =====================================================================
detect_environment
assert_true "DEBLOAT_ENV is set" "[[ -n '$DEBLOAT_ENV' ]]"
case "$DEBLOAT_ENV" in
    msys|cygwin|wsl|linux|macos|unknown) ok "DEBLOAT_ENV valid ($DEBLOAT_ENV)" ;;
    *) bad "DEBLOAT_ENV valid" "got '$DEBLOAT_ENV'" ;;
esac
assert_true "env_label non-empty" "[[ -n \"\$(env_label)\" ]]"
# On this Linux CI host there is no Windows, so it must refuse
if [[ "$DEBLOAT_ENV" == "linux" || "$DEBLOAT_ENV" == "macos" ]]; then
    assert_eq "CAN_DEBLOAT=0 on non-Windows" "$CAN_DEBLOAT" "0"
fi

# =====================================================================
section "9. Non-Windows guard rails (must refuse, not pretend)"
# =====================================================================
if [[ "$CAN_DEBLOAT" != "1" ]]; then
    out=$("$ROOT/remove-bloat.sh" --yes --safe-only 2>&1); rc=$?
    assert_eq "remove-bloat.sh exits 3 without Windows" "$rc" "3"
    assert_contains "explains why it cannot run" "$out" "cannot run here"
    assert_contains "names the environment" "$out" "Windows reachable    : no"
    assert_contains "suggests offline scan" "$out" "scan-bloat.sh --offline"

    out2=$("$ROOT/scan-bloat.sh" --offline 2>&1); rc2=$?
    assert_eq "scan --offline succeeds anywhere" "$rc2" "0"
    assert_contains "offline mode is labelled" "$out2" "offline - nothing was scanned"

    # shellcheck disable=SC2034  # only the exit code is asserted
    out3=$("$ROOT/restore-bloat.sh" </dev/null 2>&1); rc3=$?
    assert_eq "restore-bloat.sh exits 3 without Windows" "$rc3" "3"
fi

# =====================================================================
section "10. Argument parsing"
# =====================================================================
h=$("$ROOT/remove-bloat.sh" --help 2>&1)
assert_contains "remove --help shows usage" "$h" "Usage:"
assert_contains "remove --help lists --dry-run" "$h" "--dry-run"
# shellcheck disable=SC2034  # only the exit code is asserted
u=$("$ROOT/remove-bloat.sh" --bogus-flag 2>&1); urc=$?
assert_eq "unknown flag exits 2" "$urc" "2"
sh_=$("$ROOT/scan-bloat.sh" --help 2>&1)
assert_contains "scan --help shows usage" "$sh_" "Usage:"

# =====================================================================
section "11. Logging (.log + .json)"
# =====================================================================
TMP=$(mktemp -d)
# SYS_* are read by log_init/log_complete in common.sh
export SYS_PRODUCT='Windows 11 Pro' SYS_DISPLAYVER='23H2' SYS_BUILD='22631.4169'
export SYS_ARCH='x64' SYS_WINGET='Available (1.8)' SYS_ONLINE='Connected'
export SYS_WINGET_BOOL=true SYS_ONLINE_BOOL=true
QUIET=1
log_init "$TMP/t.log"
log_msg HEADER 'CATEGORY 1: Store Bloat'
log_msg SUCCESS 'Candy Crush ... SUCCESS' 'king.com.CandyCrushSaga' 'Store' 'Appx'
log_msg SKIP    'TikTok ... NOT FOUND'    'TikTok' 'Store' 'Appx'
log_msg FAIL    'Norton ... FAILED'       'Norton' 'AV'    'Win32'
log_complete 1 2469606195 1 '{"startMenu":true,"store":false}' >/dev/null
QUIET=0

assert_true "log file created"  "[[ -s '$TMP/t.log' ]]"
assert_true "json file created" "[[ -s '$TMP/t.json' ]]"
assert_contains "log has header"  "$(cat "$TMP/t.log")" "Bloatware Removal Log"
assert_contains "log has summary" "$(cat "$TMP/t.log")" "Items removed: 1"
assert_contains "log has GB"      "$(cat "$TMP/t.log")" "2.30 GB"

if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open('$TMP/t.json'))" 2>/dev/null; then
        ok "JSON is valid and parses"
    else
        bad "JSON is valid and parses" "$(python3 -c "import json;json.load(open('$TMP/t.json'))" 2>&1 | tail -1)"
    fi
    acts=$(python3 -c "import json;print(len(json.load(open('$TMP/t.json'))['actions']))" 2>/dev/null)
    assert_eq "JSON has 3 actions" "$acts" "3"
    freed=$(python3 -c "import json;print(json.load(open('$TMP/t.json'))['summary']['spaceFreedBytes'])" 2>/dev/null)
    assert_eq "JSON records bytes freed" "$freed" "2469606195"
    reboot=$(python3 -c "import json;print(json.load(open('$TMP/t.json'))['summary']['rebootRequired'])" 2>/dev/null)
    assert_eq "JSON records reboot flag" "$reboot" "True"
    gen=$(python3 -c "import json;print(json.load(open('$TMP/t.json'))['generator'])" 2>/dev/null)
    assert_eq "JSON marks bash generator" "$gen" "bash"
    val=$(python3 -c "import json;print(json.load(open('$TMP/t.json'))['validation']['store'])" 2>/dev/null)
    assert_eq "JSON embeds validation" "$val" "False"
fi

# JSON escaping of nasty input
QUIET=1
log_init "$TMP/esc.log"
log_msg FAIL 'weird "quoted" \ backslash' 'Pkg"With\Quotes' 'Cat' 'Appx'
log_complete 0 0 0 'null' >/dev/null
QUIET=0
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json;json.load(open('$TMP/esc.json'))" 2>/dev/null; then
        ok "JSON survives quotes and backslashes"
    else
        bad "JSON survives quotes and backslashes"
    fi
fi

# =====================================================================
section "12. Removal engine with MOCK Windows tools"
# =====================================================================
# Build fake reg/sc/schtasks/dism so the engine can be driven end-to-end
MOCK="$TMP/mock"; mkdir -p "$MOCK"
STATE="$TMP/state"; mkdir -p "$STATE"
echo "auto" > "$STATE/DiagTrack.mode"

cat > "$MOCK/reg.exe" <<'MOCKEOF'
#!/usr/bin/env bash
case "$1" in
  add)    echo "The operation completed successfully."; exit 0 ;;
  query)  if [[ "$*" == *NonExistentKey* ]]; then echo "ERROR: unable to find" >&2; exit 1; fi
          echo "    TestValue    REG_DWORD    0x0"; exit 0 ;;
  delete) echo "The operation completed successfully."; exit 0 ;;
  export) exit 0 ;;
esac
exit 0
MOCKEOF

cat > "$MOCK/sc.exe" <<MOCKEOF
#!/usr/bin/env bash
STATE="$STATE"
case "\$1" in
  qc)  n="\$2"
       [[ -f "\$STATE/\$n.mode" ]] || { echo "does not exist" >&2; exit 1060; }
       m=\$(cat "\$STATE/\$n.mode")
       case "\$m" in
         auto)     echo "START_TYPE : 2 AUTO_START" ;;
         demand)   echo "START_TYPE : 3 DEMAND_START" ;;
         disabled) echo "START_TYPE : 4 DISABLED" ;;
       esac; exit 0 ;;
  config) n="\$2"; mode="\$4"; echo "\$mode" > "\$STATE/\$n.mode"; echo "SUCCESS"; exit 0 ;;
  stop)   exit 0 ;;
esac
exit 0
MOCKEOF

cat > "$MOCK/schtasks.exe" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$1" == "/query" ]]; then
  [[ "$*" == *"KnownTask"* ]] && exit 0
  exit 1
fi
[[ "$1" == "/change" ]] && { echo "SUCCESS"; exit 0; }
exit 0
MOCKEOF

cat > "$MOCK/dism.exe" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$*" == *get-featureinfo* ]]; then
  [[ "$*" == *TelnetClient* ]] && { echo "State : Enabled"; exit 0; }
  echo "State : Disabled"; exit 0
fi
[[ "$*" == *disable-feature* ]] && { echo "The operation completed successfully."; exit 0; }
exit 0
MOCKEOF

chmod +x "$MOCK"/*.exe
OLD_PATH="$PATH"; export PATH="$MOCK:$PATH"

# Service state machine
assert_eq "mock service starts auto" "$(service_start_mode DiagTrack)" "auto"
assert_eq "absent service detected"  "$(service_start_mode NoSuchSvc)"  "absent"

QUIET=1; log_init "$TMP/eng.log"
r=$(remove_item 5 DiagTrack SAFE Service disabled)
QUIET=0
assert_eq "service removal returns success" "$r" "success"
assert_eq "service actually disabled"       "$(service_start_mode DiagTrack)" "disabled"

QUIET=1; r=$(remove_item 5 NoSuchSvc SAFE Service disabled); QUIET=0
assert_eq "absent service -> skipped" "$r" "skipped"

# Scheduled tasks
assert_true  "known task detected"   "task_exists 'KnownTask'"
assert_false "unknown task detected" "task_exists 'MissingTask'"
QUIET=1; r=$(remove_item 5 'KnownTask' SAFE Task ''); QUIET=0
assert_eq "task disable -> success" "$r" "success"
QUIET=1; r=$(remove_item 5 'MissingTask' SAFE Task ''); QUIET=0
assert_eq "missing task -> skipped" "$r" "skipped"

# Optional features
assert_true  "enabled feature detected"  "feature_enabled TelnetClient"
assert_false "disabled feature detected" "feature_enabled SomethingElse"
# set by remove.sh when a feature is disabled
export REBOOT_REQUIRED=0
QUIET=1; r=$(remove_item 12 TelnetClient SAFE Feature ''); QUIET=0
assert_eq "feature disable -> success" "$r" "success"
QUIET=1; r=$(remove_item 12 AlreadyOff SAFE Feature ''); QUIET=0
assert_eq "already-off feature -> skipped" "$r" "skipped"

# Registry
QUIET=1
r=$(remove_item 5 AllowTelemetry SAFE Registry 'HKLM\SOFTWARE\Test::AllowTelemetry::0')
QUIET=0
assert_eq "registry set -> success" "$r" "success"

# THE CRITICAL TEST: the guard must fire even when explicitly asked
for prot in 'Microsoft.WindowsStore' 'Microsoft.VCLibs.140.00' 'Microsoft.DesktopAppInstaller' 'Microsoft.SecHealthUI'; do
    QUIET=1; r=$(remove_item 1 "$prot" SAFE Appx ''); QUIET=0
    assert_eq "GUARD refuses $prot" "$r" "skipped"
done

# Driver guard on Win32
QUIET=1; r=$(remove_item 3 'Realtek High Definition Audio Driver' SAFE Win32 ''); QUIET=0
assert_eq "GUARD refuses driver software" "$r" "skipped"

# Dry-run must never mutate
echo "auto" > "$STATE/Fax.mode"
# DRY_RUN/QUIET are read by remove.sh and common.sh
export DRY_RUN=1; export QUIET=1
r=$(remove_item 6 Fax SAFE Service disabled)
export DRY_RUN=0; export QUIET=0
assert_eq "dry-run returns skipped" "$r" "skipped"
assert_eq "dry-run left service untouched" "$(service_start_mode Fax)" "auto"

export PATH="$OLD_PATH"

# =====================================================================
section "12b. Export formats (regression: unescaped backslashes)"
# =====================================================================
EXP=$(mktemp -d)
"$ROOT/scan-bloat.sh" --offline --csv "$EXP/o.csv" --json "$EXP/o.json" >/dev/null 2>&1
assert_true "csv export created"  "[[ -s '$EXP/o.csv' ]]"
assert_true "json export created" "[[ -s '$EXP/o.json' ]]"

if command -v python3 >/dev/null 2>&1; then
    # Task names contain Windows backslashes; these MUST be escaped
    if python3 -c "import json;json.load(open('$EXP/o.json'))" 2>/dev/null; then
        ok "exported JSON is valid (backslashes escaped)"
    else
        bad "exported JSON is valid (backslashes escaped)" \
            "$(python3 -c "import json;json.load(open('$EXP/o.json'))" 2>&1 | tail -1)"
    fi
    jn=$(python3 -c "import json;print(len(json.load(open('$EXP/o.json'))))" 2>/dev/null)
    assert_eq "JSON export has 185 items" "$jn" "185"
    hasbs=$(python3 -c "import json;print(any(chr(92) in x['name'] for x in json.load(open('$EXP/o.json'))))" 2>/dev/null)
    assert_eq "JSON preserves backslash names" "$hasbs" "True"

    if python3 -c "import csv;list(csv.DictReader(open('$EXP/o.csv')))" 2>/dev/null; then
        ok "exported CSV parses"
    else
        bad "exported CSV parses"
    fi
    cn=$(python3 -c "import csv;print(len(list(csv.DictReader(open('$EXP/o.csv')))))" 2>/dev/null)
    assert_eq "CSV export has 185 rows" "$cn" "185"
    cc=$(python3 -c "import csv;print(len(list(csv.DictReader(open('$EXP/o.csv')))[0]))" 2>/dev/null)
    assert_eq "CSV has 4 columns" "$cc" "4"
fi
rm -rf "$EXP"

# =====================================================================
section "13. Field parsing edge cases"
# =====================================================================
L='5|\Microsoft\Windows\App Experience\Task Name|SAFE|Task||has spaces'
assert_eq "parses catkey"      "$(catalog_field "$L" 1)" "5"
assert_eq "parses path w/ spaces" "$(catalog_field "$L" 2)" '\Microsoft\Windows\App Experience\Task Name'
assert_eq "parses risk"        "$(catalog_field "$L" 3)" "SAFE"
assert_eq "parses note"        "$(catalog_field "$L" 6)" "has spaces"

REGLINE='2|TaskbarDa|SAFE|Registry|HKCU\Software\Test::TaskbarDa::0|'
e=$(catalog_field "$REGLINE" 5)
assert_eq "registry path split"  "${e%%::*}" 'HKCU\Software\Test'
n2="${e#*::}"; assert_eq "registry name split" "${n2%%::*}" 'TaskbarDa'
assert_eq "registry data split"  "${e##*::}" '0'

# =====================================================================
section "14. Docs and packaging"
# =====================================================================
assert_true "bash README exists"     "[[ -f '$ROOT/README.md' ]]"
assert_true "remove-bloat.sh +x"     "[[ -x '$ROOT/remove-bloat.sh' ]]"
assert_true "scan-bloat.sh +x"       "[[ -x '$ROOT/scan-bloat.sh' ]]"
assert_true "restore-bloat.sh +x"    "[[ -x '$ROOT/restore-bloat.sh' ]]"
assert_true "test suite +x"          "[[ -x '$TEST_DIR/test_bloat.sh' ]]"

# Scripts must be LF (bash cannot run CRLF)
crlf=0
for f in "$ROOT"/*.sh "$ROOT"/lib/*.sh "$TEST_DIR"/*.sh; do
    grep -qU $'\r' "$f" 2>/dev/null && { crlf=$((crlf+1)); printf '        CRLF: %s\n' "$f"; }
done
assert_eq "no CRLF in bash scripts" "$crlf" "0"

# Shebangs
noshebang=0
for f in "$ROOT"/*.sh "$ROOT"/lib/*.sh; do
    head -1 "$f" | grep -q '^#!/usr/bin/env bash' || { noshebang=$((noshebang+1)); printf '        %s\n' "$f"; }
done
assert_eq "all scripts have bash shebang" "$noshebang" "0"

rm -rf "$TMP"

# =====================================================================
printf '\n%s================================================%s\n' "$TC_C" "$TC_N"
printf '  Passed: %s%s%s   Failed: %s%s%s\n' "$TC_G" "$PASS" "$TC_N" \
       "$([[ $FAIL -gt 0 ]] && printf '%s' "$TC_R" || printf '%s' "$TC_G")" "$FAIL" "$TC_N"
if (( FAIL > 0 )); then
    printf '\n  Failed tests:\n'
    for f in "${FAILED_NAMES[@]}"; do printf '    - %s\n' "$f"; done
fi
printf '%s================================================%s\n\n' "$TC_C" "$TC_N"
exit $(( FAIL > 0 ? 1 : 0 ))
