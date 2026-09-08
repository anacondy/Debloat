# Contributing

Thanks for helping keep the bloat list current — Microsoft and OEMs ship new
junk with every release.

## Adding a new bloatware entry

All targets live in one place: **`scripts/helpers/BloatData.ps1`**, inside
`$Global:BloatCatalog`. Add an entry to the right category:

```powershell
@{ N='Publisher.AppName'; Risk='SAFE'; T='Appx' }
```

| Field | Meaning |
|---|---|
| `N` | Match pattern. For Appx use the **package name** (locale-safe), not the display name. Wildcards allowed. |
| `Risk` | `SAFE`, `REVIEW` or `DANGER` |
| `T` | `Appx`, `Win32`, `Service`, `Task`, `Startup`, `Registry`, `Feature`, `Cleanup`, `OneDrive`, `Shortcut` |
| `Target` | For services: `Disabled` or `Manual` |
| `Path` / `Value` | For `Registry` and `Cleanup` types |
| `Note` | Shown to the user in yellow before removal |

### Rules for new entries
1. **Never** add anything that is a dependency of another app. Frameworks,
   runtimes and shell components belong in the protected list, not the catalog.
2. Use package family / package names, **never** localized display names.
3. If in doubt about breakage, mark it `REVIEW`, not `SAFE`.
4. Anything touching drivers or hardware must be `DANGER`.
5. Add a matching entry to `docs/Categories.md` and a one-liner to
   `docs/Manual-Commands.md`.

## Keeping the bash edition in sync

Every catalog change must be made in **both** places:

| Edition | File |
|---|---|
| PowerShell | `scripts/helpers/BloatData.ps1` |
| bash | `bash/lib/bloatdata.sh` |

The bash catalog uses a pipe-delimited line instead of a hashtable:

```bash
'1|Publisher.AppName|SAFE|Appx||optional note'
# CATKEY|NAME|RISK|TYPE|EXTRA|NOTE
```

`EXTRA` carries type-specific data:
- `Service` -> start mode for `sc.exe`: `auto`, `demand` or `disabled`
- `Registry` -> `HIVE\PATH::VALUENAME::DATA`
- `Cleanup` -> a path template such as `%TEMP%`

**CI fails the build if the two catalogs drift.** The `parity` job diffs them
entry by entry, and test 7 in the bash suite additionally asserts that both
`Test-Protected` implementations agree on every probe package. Adding an entry
to one edition without the other will be caught.

## Adding a protected package

Add to `$Global:ProtectedExact` (exact/prefix match) or
`$Global:ProtectedContains` (substring guard) in `BloatData.ps1`, and document
the reason in `docs/Protected-Packages.md`.

## Testing before you open a PR

### Bash edition

```bash
shellcheck -S warning -x bash/*.sh bash/lib/*.sh bash/tests/*.sh
./bash/tests/test_bloat.sh          # 164 assertions, runs on any OS
./bash/scan-bloat.sh --offline      # catalog listing, no Windows needed
```

The suite runs anywhere — it mocks `reg.exe`, `sc.exe`, `schtasks.exe` and
`dism.exe` so the removal engine is exercised end to end without a Windows host.

### PowerShell edition

```powershell
# 1. Syntax check everything
Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
  $e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e)
  if ($e.Count) { "FAIL $($_.Name)" }
}

# 2. Scan-only run — must not error and must not list protected packages
.\scripts\Scan-Bloat.ps1

# 3. Dry run
.\scripts\Remove-Bloat.ps1 -DryRun -SafeOnly
```

Please state in the PR which build you tested on (edition, version, arch).
Ideally test in a VM with a checkpoint.

## Style
- PowerShell 5.1 compatible (that is what ships with Windows 11).
- Comment-based help on every public function.
- Short, readable commands. No obfuscated one-liners in the scripts themselves.
- No external module dependencies.
