# Windows 11 Debloat

**Safely detect and remove Windows 11 bloatware, OEM junk, trial antivirus, telemetry and modern bloat (Copilot, Widgets, Teams, Phone Link).**

One command. Shows you everything first. Makes a restore point. Never touches the parts of Windows that matter.

---

## ⚠️ Safety Warning — read this first

> This script modifies your Windows installation. Although it creates a
> **System Restore Point** and **registry backups** automatically, and refuses to
> touch a hard-coded list of critical system packages, **you run it at your own risk.**
>
> - **Back up important files first.** OneDrive removal in particular can strand files.
> - **Test in a VM** if you are deploying this to more than one machine.
> - **On a work or school PC, ask IT first.** Domain policy may fight the changes.
> - Items marked 🔴 **DANGER** can break hardware support. The script refuses them
>   unless you literally type `I ACCEPT`.
> - No warranty. See [LICENSE](LICENSE).

---

## Quick Start

Open **PowerShell as Administrator** (Windows key → type `Terminal` → right-click → *Run as administrator*), then paste:

```powershell
irm https://raw.githubusercontent.com/anacondy/Debloat/main/scripts/Remove-Bloat.ps1 | iex
```

Prefer to read the code first? (recommended)

```powershell
git clone https://github.com/anacondy/Debloat.git
cd Debloat
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\scripts\Scan-Bloat.ps1        # look, change nothing
.\scripts\Remove-Bloat.ps1      # interactive removal
```

**Nothing is removed until you confirm.** The default path is: scan → show → dry-run → confirm.

### Prefer bash?

A full bash edition lives in [`bash/`](bash/) — same catalog, same protected
list, same safety model:

```bash
cd Debloat/bash
./scan-bloat.sh          # look, change nothing
./remove-bloat.sh        # interactive removal
```

Run it from **Git Bash, MSYS2, Cygwin, or WSL** with administrator rights.

> ⚠️ **Bash cannot debloat Linux.** These scripts clean a *Windows*
> installation; bash is only the driver. On native Linux or macOS
> `remove-bloat.sh` refuses to run and exits 3 rather than pretending. Use
> `./scan-bloat.sh --offline` to inspect the catalog from any OS.
>
> Appx/Store apps, restore points and Defender have no Windows CLI equivalent,
> so those specific steps bridge to `powershell.exe`. Services, tasks, registry
> and optional features use native `sc`/`schtasks`/`reg`/`dism`.
> See [bash/README.md](bash/README.md) for the full breakdown.

---

## What This Script Does

1. Checks it is running as Administrator (offers to relaunch elevated).
2. Detects your Windows edition, build, architecture, winget availability and internet state.
3. Scans Appx packages, provisioned packages, installed programs, services, scheduled tasks, startup entries, optional features and disk caches.
4. Removes anything on the **protected list** from the results — before you can even see it.
5. Tags every finding 🟢 SAFE / 🟡 REVIEW / 🔴 DANGER, force-tagging driver software as DANGER.
6. Shows you a categorized, colour-coded report and a **dry run** of the exact actions.
7. On confirmation: creates a **System Restore Point**, exports registry branches, snapshots your app list.
8. Removes items with 2 retries and a winget fallback. A failure never aborts the run.
9. If antivirus was removed, **turns Windows Defender back on** and verifies it.
10. Runs 7 post-removal validation checks and prints a fix command for any failure.
11. Writes a human-readable `.log` and a machine-readable `.json` to your Desktop.

---

## What Gets Removed

| # | Category | Risk | Examples |
|---|---|---|---|
| 1 | Microsoft Store Bloat | 🟢 SAFE | Candy Crush, TikTok, Netflix, Spotify, Disney+, Instagram, Solitaire, Bing apps |
| 2 | Windows 11 Modern Bloat | 🟢 / 🟡 | Copilot, Widgets, Teams (personal), Phone Link, Dev Home, Power Automate |
| 3 | OEM / Manufacturer Bloat | 🟡 / 🔴 | Dell SupportAssist, HP Support Assistant, Lenovo Vantage, MyASUS, Acer Care |
| 4 | Free / Trial Antivirus | 🟢 SAFE | McAfee, Norton, Avast, AVG, Avira, Kaspersky, Webroot, Bitdefender, Trend Micro |
| 5 | Telemetry & Privacy | 🟢 SAFE | DiagTrack, dmwappushservice, CEIP tasks, advertising ID, activity history |
| 6 | Unnecessary Services | 🟢 / 🟡 | Fax, Remote Registry, Maps Broker, Retail Demo, Windows Insider |
| 7 | Startup Apps & Tasks | 🟢 / 🟡 | Adobe updaters, Google Update, Office telemetry, Discord, Epic |
| 8 | OneDrive Integration | 🟡 REVIEW | Uninstall + unpin from Explorer (opt-in) |
| 9 | Edge Leftovers | 🟡 REVIEW | Prelaunch, startup boost, desktop shortcut — **never Edge itself** |
| 10 | Cortana & Search | 🟢 SAFE | Bing web search, search highlights, Cortana |
| 11 | Gaming & Xbox | 🟡 REVIEW | Game Bar, Xbox App, Game DVR, Xbox services |
| 12 | Optional Features | 🟢 / 🟡 / 🔴 | SMB 1.0, PowerShell 2.0, Telnet, XPS, Fax & Scan |
| 13 | Background Space Wasters | 🟢 / 🟡 | Temp files, Delivery Optimization cache, crash dumps, Windows.old |

Full detail: **[docs/Categories.md](docs/Categories.md)**

---

## How It Works

```
  ┌────────────────────────────────────────────────────────┐
  │ 1  ADMIN CHECK      elevate or instruct                │
  ├────────────────────────────────────────────────────────┤
  │ 2  DETECT           edition · build · arch · winget    │
  │                     · internet                         │
  ├────────────────────────────────────────────────────────┤
  │ 3  SCAN             Appx · provisioned · Win32 ·       │
  │                     services · tasks · startup ·       │
  │                     features · disk                    │
  │                            │                           │
  │                            ▼                           │
  │                   ┌──────────────────┐                 │
  │                   │ PROTECTED LIST   │  ← filtered out │
  │                   │ (never shown)    │                 │
  │                   └──────────────────┘                 │
  ├────────────────────────────────────────────────────────┤
  │ 4  CATEGORIZE       🟢 SAFE  🟡 REVIEW  🔴 DANGER      │
  ├────────────────────────────────────────────────────────┤
  │ 5  DISPLAY          colour-coded report + sizes        │
  ├────────────────────────────────────────────────────────┤
  │ 6  MENU             [1-13] [A]ll safe [C]ustom         │
  │                     [S]can only [Q]uit                 │
  ├────────────────────────────────────────────────────────┤
  │ 7  DRY RUN          exact action list                  │
  ├────────────────────────────────────────────────────────┤
  │ 8  CONFIRM          y/N   (DANGER needs "I ACCEPT")    │
  ├────────────────────────────────────────────────────────┤
  │ 9  BACKUP           restore point · registry .reg ·    │
  │                     Appx snapshot JSON                 │
  ├────────────────────────────────────────────────────────┤
  │ 10 EXECUTE          retry ×2 → winget fallback → log   │
  ├────────────────────────────────────────────────────────┤
  │ 11 DEFENDER         if AV removed: enable + verify     │
  ├────────────────────────────────────────────────────────┤
  │ 12 VALIDATE         Start · Search · Store · Update ·  │
  │                     Settings · Explorer · Defender     │
  ├────────────────────────────────────────────────────────┤
  │ 13 REPORT           .log + .json + reboot advice       │
  └────────────────────────────────────────────────────────┘
```

---

## Safety Features

| Feature | Detail |
|---|---|
| **System Restore Point** | Mandatory, timestamped. Bypasses the 24-hour frequency limit. Skippable only with `-SkipRestorePoint`. |
| **Registry backup** | Affected branches exported as `.reg` to `backups/<timestamp>/`. |
| **App snapshot** | Full Appx + provisioned package list saved as JSON before any change. |
| **Protected list** | ~30 exact packages + 15 substring guards. Checked at scan, at filter, and again immediately before removal. |
| **Driver protection** | 25+ keyword patterns force any driver software to 🔴 DANGER, excluded from bulk removal. |
| **Dry run** | Always shown. `-DryRun` exits before making changes. |
| **Retry + fallback** | 2 retries → winget → log and continue. "Package in use" and "not found" handled gracefully. |
| **Defender handoff** | Removing AV auto-enables Defender, updates definitions, quick-scans, and screams in red if it fails. |
| **Validation** | 7 checks with a copy-pasteable fix command for each failure. |
| **Reversible by design** | Services are set to Manual/Disabled, never deleted. Tasks are disabled, never unregistered. |
| **Full logging** | `.log` + `.json` on your Desktop; last 10 kept. |

More: **[docs/Safety.md](docs/Safety.md)**

---

## "Do Not Touch" Packages

The script **refuses** to remove these, even with `-Force`:

**Critical apps** — Store, StorePurchaseApp, Calculator, Notepad, Paint, Snipping Tool, Terminal, Photos, **DesktopAppInstaller (winget)**, SecHealthUI (Windows Security), Settings, AccountsControl, AAD.BrokerPlugin

**Frameworks & runtimes** — anything containing `Framework`, `Runtime`, `VCLibs`, `UI.Xaml`, `AppRuntime`, `Native.Framework`, `Native.Runtime`, `DirectX`

**Shell** — ShellExperienceHost, StartMenuExperienceHost, Windows.Search, CloudExperienceHost, NarratorShell

**Languages** — LanguageComponents, LanguageExperiencePack*

**Also never done:** disabling Windows Update, disabling Defender, deleting services, removing Edge or WebView2.

Why each one: **[docs/Protected-Packages.md](docs/Protected-Packages.md)**

---

## Screenshots

<details>
<summary>Detection & scan</summary>

```
  ===============================================================
    WINDOWS 11 BLOATWARE REMOVAL
    Safe  |  Reversible  |  Logged
  ===============================================================

  [1/6] Detecting system...
        OS       : Windows 11 Pro 23H2 (Build 22631.4169)
        Edition  : Professional
        Arch     : x64
        Device   : Dell Inc. Inspiron 15 3520
        Winget   : v1.8.1911
        Internet : Connected
        Log      : C:\Users\you\Desktop\BloatRemoval-2026-09-08-143215.log

  [2/6] Scanning for bloat (protected packages excluded)...
        Found 34 removable item(s) across 8 categories.
        Protected 6 driver-related program(s) from removal.
```
</details>

<details>
<summary>Findings report</summary>

```
  [1] Microsoft Store Bloat  (11 items, ~840 MB)
       SAFE   king.com.CandyCrushSaga  [Remove-AppxPackage]
       SAFE   king.com.CandyCrushSaga (provisioned)  [Remove-AppxProvisionedPackage]
       SAFE   SpotifyAB.SpotifyMusic  [Remove-AppxPackage]
       SAFE   Microsoft.BingNews  [Remove-AppxPackage]

  [3] OEM / Manufacturer Bloat  (4 items, ~610 MB)
       REVIEW Dell SupportAssist  [QuietUninstall]
       DANGER Realtek Audio Driver  [msiexec]
              note: Driver-related — removing may break hardware

  [4] Free / Trial Antivirus & Security Suites  (1 items, ~412 MB)
       SAFE   McAfee LiveSafe  [msiexec]
```
</details>

<details>
<summary>Menu</summary>

```
  ---------------------------------------------------------------
   [1-13] Choose categories (comma separated, e.g. 1,2,5)
   [A]    Remove all SAFE items only  (recommended)
   [C]    Custom item-by-item selection
   [S]    Scan only — write report and exit
   [Q]    Quit without changes
  ---------------------------------------------------------------
  Your choice:
```
</details>

<details>
<summary>Summary</summary>

```
  -- VALIDATION --
[14:35:00]  start Menu .................... OK
[14:35:01]  search ........................ OK
[14:35:02]  store ......................... OK
[14:35:03]  update ........................ OK
[14:35:04]  settings ...................... OK
[14:35:05]  file Explorer ................. OK
[14:35:06]  defender ...................... OK

===============================================================
  SUMMARY
  Items removed: 27
  Estimated space freed: ~2.31 GB
  Validation: ALL PASSED
  Reboot recommended: YES
===============================================================
```
</details>

---

## Manual Commands

Don't want to run a script? Every category has copy-paste one-liners in
**[docs/Manual-Commands.md](docs/Manual-Commands.md)**.

```powershell
# Example: nuke Candy Crush for all users AND stop it returning for new ones
Get-AppxPackage -AllUsers -Name 'king.com.CandyCrushSaga' | Remove-AppxPackage -AllUsers
Get-AppxProvisionedPackage -Online | Where DisplayName -like '*CandyCrush*' |
  Remove-AppxProvisionedPackage -Online
```

---

## Reinstall Guide

```powershell
.\scripts\Restore-Bloat.ps1
```

| Option | Use when |
|---|---|
| 1 · System Restore Point | You want everything back, now |
| 2 · Import registry backup | A tweak or service change caused a problem |
| 3 · Re-register built-in apps | Start Menu / Store / Settings misbehaving |
| 4 · Reinstall a specific app | You miss one app |
| 5 · Reinstall OneDrive | |

Single app by hand:
```powershell
winget install --id 9WZDNCRFJBMP --source msstore      # Microsoft Store
Get-AppxPackage -AllUsers *Calculator* | ForEach-Object {
  Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" }
```

---

## Prevent Bloat from Returning

Answer **yes** to the prompt, or run with `-PreventReprovisioning`. It sets:

```
HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent
  DisableWindowsConsumerFeatures      = 1
  DisableCloudOptimizedContent        = 1
  DisableConsumerAccountStateContent  = 1

HKLM\...\CurrentVersion\ContentDeliveryManager
  SilentInstalledAppsEnabled  = 0
  PreInstalledAppsEnabled     = 0
  OemPreInstalledAppsEnabled  = 0
```

⚠️ Major feature updates (23H2 → 24H2 → 25H2) can still restore some apps.
Just re-run `.\scripts\Remove-Bloat.ps1 -SafeOnly` afterwards.

Details & Group Policy equivalents: **[docs/Prevent-Reprovisioning.md](docs/Prevent-Reprovisioning.md)**

---

## Windows Edition Differences

| | Home | Pro | Enterprise / Edu | LTSC |
|---|:--:|:--:|:--:|:--:|
| Bloat shipped | heavy | moderate | light | none |
| `gpedit.msc` | ❌ | ✅ | ✅ | ✅ |
| Policy registry keys honoured | ✅ | ✅ | ✅ | ✅ |
| Hyper-V / Sandbox | ❌ | ✅ | ✅ | ✅ |
| Copilot / Widgets present | ✅ | ✅ | ✅ | ❌ |

The script auto-detects and skips what doesn't apply.
Full table: **[docs/Windows-Editions.md](docs/Windows-Editions.md)**

---

## Driver Safety

**The single biggest risk in any debloat script is nuking a driver utility.**

This one force-tags anything matching 25+ driver keywords as 🔴 DANGER,
excludes it from `[A] Remove all SAFE`, and requires you to type `I ACCEPT`:

> Realtek · Dolby · Bang & Olufsen · Nahimic · Waves MaxxAudio · Conexant ·
> Cirrus Logic · Intel Wireless · Qualcomm · Killer · Synaptics · ELAN · Alps ·
> Precision Touchpad · Intel Graphics · NVIDIA · AMD Software / Chipset ·
> Radeon · Fingerprint / Goodix / Validity · Windows Hello · Intel Management
> Engine · Serial IO · GPIO · Thunderbolt · Card Reader · RealSense

See what it caught on your PC:
```powershell
.\scripts\Scan-Bloat.ps1
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `running scripts is disabled` | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` |
| "Access is denied" | You're not elevated. Right-click Terminal → *Run as administrator* |
| Restore point fails | Turn on System Protection: Start → "Create a restore point" → Configure |
| "Package is in use" | Close the app (check the tray) and re-run. Script retries 2× then skips |
| AV leftovers | Run the vendor tool: McAfee MCPR, Norton RnR, avastclear, kavremover |
| Defender won't start | Reboot first (AV drivers unload at boot), then `Start-Service WinDefend` |
| Start Menu broken | `Get-AppxPackage -AllUsers \| % { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" }` |
| Bloat came back | Expected after feature updates. Re-run with `-SafeOnly` |
| Widgets button still there | `Stop-Process -Name explorer -Force` |

More: **[docs/Safety.md](docs/Safety.md)**

---

## FAQ

**Is this safe?**
Safer than most. Restore point + registry backup + a triple-checked protected
list + dry run + post-run validation. But it still modifies Windows — read the
warning at the top.

**Will it break my PC?**
It's designed not to. `[A] Remove all SAFE items` only touches things with no
known dependencies. Every DANGER item requires typing `I ACCEPT`.

**Do I need internet?**
No. It detects offline state and skips network steps (winget fallback, Defender
definition updates). Everything else works.

**Does it work on Windows 10?**
Untested and unsupported. It warns if the build is below 22000.

**Will Microsoft reinstall this stuff?**
Not for normal updates if you enable reprovisioning prevention. Major feature
updates can. Re-run the script.

**Can I run it more than once?**
Yes. Already-removed items are logged as SKIP, not errors. Re-running after
every feature update is the recommended workflow.

**Does it remove Edge?**
No. Edge and WebView2 are required by Windows components and many apps. It only
disables prelaunch/startup boost and removes the desktop shortcut.

**What about my antivirus subscription?**
If you paid for it, don't remove it — deselect category 4. The script targets
preinstalled trials.

**Non-English Windows?**
Yes. It matches on package family names and winget IDs, never localized display
names.

**ARM64?**
Yes. Appx/service/task/registry work identically. Some x64-only OEM uninstallers
may fail — they're logged and skipped.

**Can I run this from bash / on Linux?**
There is a full bash edition in [`bash/`](bash/). It runs from Git Bash, MSYS2,
Cygwin or WSL and cleans the *Windows* system. It cannot debloat Linux itself —
there is no Windows bloatware on Linux — and it exits with code 3 rather than
pretending otherwise. `./bash/scan-bloat.sh --offline` inspects the catalog from
any OS.

**How do I undo everything?**
`.\scripts\Restore-Bloat.ps1` → option 1 (System Restore Point).

---

## Contributing

New bloat ships every release. Adding an entry is one line in
`scripts/helpers/BloatData.ps1`:

```powershell
@{ N='Publisher.AppName'; Risk='SAFE'; T='Appx' }
```

Read **[CONTRIBUTING.md](CONTRIBUTING.md)** for the rules (use package names not
display names; when in doubt mark REVIEW; driver-adjacent = DANGER).

---

## Changelog

### v1.1.0 — 2026-09-08
- **Added a complete bash edition** (`bash/`) — `remove-bloat.sh`,
  `scan-bloat.sh`, `restore-bloat.sh` plus a four-module library
- Same 185-entry catalog, 27+17 protected guards and 34 driver keywords,
  enforced identically to the PowerShell edition
- Native `sc`/`schtasks`/`reg`/`dism` used wherever Windows provides a CLI;
  PowerShell bridged only for Appx, restore points and Defender
- Honest refusal (exit 3) on non-Windows hosts instead of silent no-ops;
  `scan-bloat.sh --offline` works anywhere
- 164-assertion test suite runnable on any OS, including a mock Windows
  toolchain that drives the removal engine end to end
- CI extended: ShellCheck, LF-ending check, bash suite on Ubuntu *and* Git Bash,
  and a catalog-parity job that fails the build if the two editions drift

### v1.0.0 — 2026-09-08
- Initial release
- 13 categories, 185 catalog targets
- Protected list: 28 exact packages + 16 substring guards, checked 3×
- Driver detection with 25+ keyword patterns, force-tagged DANGER
- Mandatory System Restore Point + registry export + Appx snapshot
- Retry ×2 with winget fallback; graceful handling of in-use / missing packages
- Automatic Windows Defender handoff after antivirus removal
- 7-point post-removal validation with per-failure fix commands
- Dual logging (human `.log` + machine `.json`), 10-log retention
- `Scan-Bloat.ps1` (read-only) and `Restore-Bloat.ps1` (5 restore paths)
- Reprovisioning prevention for all editions including Home
- Full docs: Categories, Manual Commands, Safety, Protected Packages, Editions, Reprovisioning

---

## Repository Structure

```
├── README.md
├── LICENSE                    MIT
├── CONTRIBUTING.md
├── .gitignore
├── scripts/
│   ├── Remove-Bloat.ps1       master interactive script
│   ├── Restore-Bloat.ps1      5-option restore menu
│   ├── Scan-Bloat.ps1         read-only scan + CSV/JSON export
│   └── helpers/
│       ├── BloatData.ps1          catalog + protected list
│       ├── Get-SystemInfo.ps1     edition / build / arch / winget / net
│       ├── Get-BloatInventory.ps1 full system scan
│       ├── Remove-SafeItem.ps1    removal with retry + fallback
│       ├── Enable-Defender.ps1    AV handoff + verification
│       ├── Test-CoreFunctions.ps1 post-removal validation
│       ├── Backup-Registry.ps1    .reg export + Appx snapshot
│       ├── Write-RemovalLog.ps1   structured logging
│       └── Get-DriverInfo.ps1     driver identification
├── bash/                      bash edition (same catalog + safety model)
│   ├── remove-bloat.sh        master interactive script
│   ├── scan-bloat.sh          read-only scan, --offline works on any OS
│   ├── restore-bloat.sh       five restore paths
│   ├── README.md              bash-specific docs and limitations
│   ├── lib/
│   │   ├── common.sh          env detection, PowerShell bridge, logging
│   │   ├── bloatdata.sh       protected list + 185-entry catalog
│   │   ├── detect.sh          system info and enumeration
│   │   └── remove.sh          removal engine, Defender, validation
│   └── tests/
│       └── test_bloat.sh      164-assertion suite, runs on any OS
├── docs/
│   ├── Categories.md
│   ├── Manual-Commands.md
│   ├── Safety.md
│   ├── Protected-Packages.md
│   ├── Windows-Editions.md
│   └── Prevent-Reprovisioning.md
├── logs/
└── backups/
```

---

## License

MIT — see [LICENSE](LICENSE). Provided as-is, without warranty of any kind.
