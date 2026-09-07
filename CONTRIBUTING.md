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

## Adding a protected package

Add to `$Global:ProtectedExact` (exact/prefix match) or
`$Global:ProtectedContains` (substring guard) in `BloatData.ps1`, and document
the reason in `docs/Protected-Packages.md`.

## Testing before you open a PR

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
