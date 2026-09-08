# Bash Edition

Bash counterpart to the PowerShell scripts in `../scripts/`. Same catalog, same
protected list, same safety model — driven from a shell instead of a console.

---

## ⚠️ Read this first: bash cannot debloat Linux

There is no such thing as "Windows bloatware on Linux." These scripts clean a
**Windows 11 installation**. Bash is just the driver.

| Where you run it | Works? | Why |
|---|:--:|---|
| **Git Bash / MSYS2** on Windows | ✅ | Talks to the real Windows |
| **Cygwin** on Windows | ✅ | Same |
| **WSL** (interop enabled) | ✅ | Reaches the host via `/mnt/c` |
| **Native Linux** | ❌ | No Windows to clean |
| **macOS** | ❌ | No Windows to clean |

On native Linux or macOS, `remove-bloat.sh` **refuses to run and exits 3** with
an explanation. It will never pretend to have done something. You can still
inspect the catalog anywhere with `./scan-bloat.sh --offline`.

### Why some operations still call PowerShell

Windows exposes no command-line tool for **Appx/MSIX packages** — no
`reg.exe`, `sc.exe` or `wmic` equivalent exists. Store apps (Candy Crush,
Copilot, Teams, Xbox) can only be enumerated and removed through the
`Get-AppxPackage` / `Remove-AppxPackage` API.

So the bash edition uses native Windows CLI tools wherever they exist and
bridges to `powershell.exe` only where the platform leaves no choice:

| Operation | Tool used |
|---|---|
| Services | `sc.exe` (native) |
| Scheduled tasks | `schtasks.exe` (native) |
| Registry tweaks | `reg.exe` (native) |
| Registry backup | `reg export` (native) |
| Optional features | `dism.exe` (native) |
| Installed programs | `reg query` + `winget` (native) |
| System info | `reg query` (native) |
| **Appx packages** | `powershell.exe` (no alternative exists) |
| **Restore point** | `powershell.exe` (`Checkpoint-Computer`) |
| **Defender control** | `powershell.exe` (`Set-MpPreference`) |

If you would rather not have the PowerShell dependency at all, use
`../scripts/Remove-Bloat.ps1` directly — it is the primary implementation.

---

## Quick Start

Open **Git Bash as Administrator** (right-click the icon → *Run as
administrator*), then:

```bash
cd Debloat/bash
./scan-bloat.sh          # look, change nothing
./remove-bloat.sh        # interactive removal
```

Non-interactive:

```bash
./remove-bloat.sh --dry-run             # show actions, change nothing
./remove-bloat.sh --safe-only --yes     # all SAFE items, no prompts
./remove-bloat.sh --categories 1,2,5    # specific categories
```

---

## Scripts

| Script | Purpose |
|---|---|
| `remove-bloat.sh` | Master interactive removal (mirrors `Remove-Bloat.ps1`) |
| `scan-bloat.sh` | Read-only inventory; `--offline` works on any OS |
| `restore-bloat.sh` | Five restore paths (mirrors `Restore-Bloat.ps1`) |
| `tests/test_bloat.sh` | 164-assertion test suite; runs on any OS |

### `lib/`

| File | Contents |
|---|---|
| `common.sh` | Environment detection, PowerShell bridge, colours, logging |
| `bloatdata.sh` | Protected list, driver keywords, 185-entry catalog |
| `detect.sh` | Windows system info, package/service/task enumeration |
| `remove.sh` | Removal engine, restore point, Defender handoff, validation |

---

## Options

### `remove-bloat.sh`

| Flag | Effect |
|---|---|
| `-n, --dry-run` | Print every action, change nothing |
| `-y, --yes` | Skip confirmation prompts |
| `-s, --safe-only` | Only act on SAFE items |
| `-c, --categories LIST` | Comma-separated category numbers |
| `--skip-restore-point` | Skip the restore point (not advised) |
| `--log PATH` | Custom log location |
| `-h, --help` | Usage |

### `scan-bloat.sh`

| Flag | Effect |
|---|---|
| `--offline` | Print the catalog without scanning (any OS) |
| `--csv FILE` | Export findings to CSV |
| `--json FILE` | Export findings to JSON |

---

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success (or user cancelled cleanly) |
| 1 | Aborted after a failure (e.g. restore point declined) |
| 2 | Bad command-line arguments |
| 3 | **No Windows reachable** — wrong OS for this script |
| 4 | Not running as Administrator |

Scriptable:

```bash
./remove-bloat.sh --safe-only --yes
case $? in
  0) echo "cleaned" ;;
  3) echo "not a Windows host - skipping" ;;
  4) echo "need admin" ;;
esac
```

---

## Safety model (identical to the PowerShell edition)

- **Protected list** — 27 exact packages + 17 substring guards, checked before
  the scan *and* again inside `remove_item`, so a protected package cannot be
  removed even if selected by hand.
- **Driver guard** — 34 keyword patterns force any driver software to DANGER;
  `remove_item` refuses Win32 removals that match.
- **Risk levels** — SAFE / REVIEW / DANGER. `[A]` only ever touches SAFE, and
  DANGER items require typing `I ACCEPT`.
- **Mandatory dry run** before the confirmation prompt.
- **System Restore Point** + `reg export` backups before any change.
- **Retry ×2** then log and continue — a failure never aborts the run.
- **Defender handoff** after antivirus removal, with a red warning if it fails.
- **7-point validation** afterwards, each failure paired with a fix command.
- **Dual logs** — `.log` and `.json`, written to `../logs/`.

---

## Testing

```bash
./tests/test_bloat.sh       # 164 assertions
./tests/test_bloat.sh -v    # show each passing assertion
```

The suite runs **on any OS** — no Windows required — and covers:

1. Library loading
2. 33 packages that must always be protected
3. 16 packages that must remain removable (no over-blocking)
4. Case-insensitivity of the guard
5. Driver detection (15 positive, 6 negative)
6. Catalog integrity — field count, valid risks/types/categories, no protected
   entry in the catalog, well-formed registry specs, valid `sc.exe` start modes
7. **Cross-implementation parity** — diffs the bash catalog against the
   PowerShell one and asserts both `Test-Protected` implementations agree on
   every probe
8. Environment detection
9. Non-Windows guard rails — asserts the correct refusal and exit code
10. Argument parsing
11. Logging: valid JSON, correct counts, escaping of quotes/backslashes
12. **Removal engine against mock `reg.exe`/`sc.exe`/`schtasks.exe`/`dism.exe`**
    — verifies a service really changes state, the protected guard fires when
    explicitly asked, and dry-run mutates nothing
13. Export formats — regression cover for unescaped backslashes in the
    JSON/CSV output (task paths like `\Microsoft\Windows\...`)
14. Field-parsing edge cases (paths with spaces and backslashes)
15. Packaging — executable bits, LF endings, shebangs

Static analysis:

```bash
shellcheck -S warning -x *.sh lib/*.sh    # zero warnings
```

### What the tests cannot cover

The mock harness proves the **logic** is correct. It cannot prove Windows
behaves as expected — that requires a real machine. Before trusting this on a
system you care about:

```bash
./scan-bloat.sh              # confirm detection works
./remove-bloat.sh --dry-run  # confirm the action list looks right
```

Then run it for real in a VM with a snapshot.

---

## Keeping the two editions in sync

`lib/bloatdata.sh` and `../scripts/helpers/BloatData.ps1` must stay identical.
Test 7 fails the build if they drift, so adding an entry to one without the
other is caught automatically. See `../CONTRIBUTING.md`.
