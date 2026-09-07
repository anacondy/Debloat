# Windows 11 Edition Differences

The script auto-detects your edition (`EditionID`) and silently skips anything
unavailable — but here is what actually differs.

## Detection

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
  Select ProductName, EditionID, DisplayVersion, CurrentBuild, UBR
```

| EditionID | Edition |
|---|---|
| `Core` / `CoreSingleLanguage` | Home |
| `Professional` | Pro |
| `Enterprise` | Enterprise |
| `Education` / `ProEducation` | Education |
| `EnterpriseS` / `IoTEnterpriseS` | **LTSC** |

## Feature matrix

| Capability | Home | Pro | Enterprise / Education | LTSC |
|---|:--:|:--:|:--:|:--:|
| Group Policy Editor (`gpedit.msc`) | ❌ | ✅ | ✅ | ✅ |
| Policy registry keys still work | ✅¹ | ✅ | ✅ | ✅ |
| Hyper-V | ❌ | ✅ | ✅ | ✅ |
| Windows Sandbox | ❌ | ✅ | ✅ | ✅ |
| BitLocker (full) | ❌² | ✅ | ✅ | ✅ |
| Consumer experiences policy | ✅¹ | ✅ | ✅ | n/a³ |
| Ships with Store bloat | ✅ heavy | ✅ moderate | ⚠️ light | ❌ none |
| Ships with Copilot/Widgets | ✅ | ✅ | ✅ | ❌ |
| Microsoft Store included | ✅ | ✅ | ✅ | ❌⁴ |
| Telemetry can be set to "Security" (0) | ❌⁵ | ❌⁵ | ✅ | ✅ |

¹ Home has no GUI policy editor, but the underlying `HKLM:\SOFTWARE\Policies\...`
values are still honoured. The script writes registry directly, so it works on Home.
² Home gets "Device Encryption" only, on supported hardware.
³ LTSC has no consumer content to disable.
⁴ LTSC ships without the Store; `Restore-Bloat.ps1` option 4 needs winget or a manual install.
⁵ On Home/Pro, `AllowTelemetry=0` is clamped up to 1 (Basic/Required) by Windows.

## What this means per edition

### Home
- **Most bloat.** Expect the longest findings list — candy games, TikTok,
  Spotify promos, plus full OEM payload.
- Group Policy items are applied as registry values instead — same effect.
- Categories 1, 2, 5, 7, 10, 13 give the biggest wins.
- Hyper-V / Sandbox entries in category 12 simply won't appear.

### Pro
- Moderate bloat. Same removals as Home plus real Group Policy support.
- Category 12 will show Hyper-V, Sandbox and Virtual Machine Platform —
  all REVIEW/DANGER. Leave Virtual Machine Platform alone if you use WSL2.

### Enterprise / Education
- Light bloat; images are usually already managed.
- ⚠️ **Domain / Intune policies override local changes.** A tweak may revert at
  the next policy refresh (`gpupdate /force`). Talk to IT before running this.
- Telemetry can genuinely be set to 0 (Security level) here.

### LTSC (EnterpriseS / IoTEnterpriseS)
- Essentially bloat-free by design: no Store, no Copilot, no Widgets, no
  consumer apps. A scan typically returns only telemetry services and disk cleanup.
- The script detects LTSC (`IsLTSC = true`) and you should expect a very short list.
- Don't remove `Microsoft.DesktopAppInstaller` — on LTSC winget is often the
  *only* way to install anything.

## Build differences

| Version | Build | Notes |
|---|---|---|
| 22H2 | 22621 | Widgets present, Copilot arrives late via update |
| 23H2 | 22631 | Copilot as a taskbar button, `MicrosoftWindows.Client.WebExperience` |
| 24H2 | 26100 | Copilot becomes a normal removable app; Recall on Copilot+ PCs; new Outlook pushed |
| 25H2+ | 26200+ | More AI components; package names shift — the script matches by name pattern so it degrades gracefully |

The script reads `DisplayVersion` and `CurrentBuild` and just skips packages
that don't exist on your build — a "not found" is logged as SKIP, never an error.

## Architecture

- **x64** — everything works.
- **ARM64** — Appx, service, task and registry operations are identical. Some
  OEM Win32 uninstallers and vendor AV cleanup tools are x64-only; if one fails
  the script logs it and continues, and winget is tried as a fallback.
