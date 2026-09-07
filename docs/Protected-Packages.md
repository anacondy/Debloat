# "Do Not Touch" — Protected Packages

These are **hard-coded refusals**. Even if you select them manually, even with
`-Force`, `Remove-SafeItem` checks `Test-Protected` first and skips them.

## How the guard works

Two lists in `scripts/helpers/BloatData.ps1`:

1. **`$ProtectedExact`** — prefix match (`Name -like "$p*"`), so
   `Microsoft.WindowsStore` also protects `Microsoft.WindowsStore_8wekyb3d8bbwe`.
2. **`$ProtectedContains`** — substring guard, catches anything with
   `Framework`, `Runtime`, `VCLibs` etc. in the name regardless of publisher.

The inventory scanner filters twice (per item and again on the final result set)
and the remover checks a third time immediately before acting.

## 1. Critical system packages

| Package | Why it's protected |
|---|---|
| `Microsoft.WindowsStore` | No Store = no way to reinstall anything |
| `Microsoft.StorePurchaseApp` | Store purchase/licensing backend |
| `Microsoft.WindowsCalculator` | Core app, tiny, no telemetry |
| `Microsoft.WindowsNotepad` | Core app |
| `Microsoft.Paint` | Core app |
| `Microsoft.ScreenSketch` | Snipping Tool — also handles the PrtScn key |
| `Microsoft.WindowsTerminal` | Default console host on 22H2+ |
| `Microsoft.Windows.Photos` | Default image handler; removal breaks previews |
| `Microsoft.DesktopAppInstaller` | **This IS winget.** Removing it kills the fallback removal method |
| `Microsoft.SecHealthUI` | Windows Security UI — you would lose all Defender controls |
| `Windows.immersivecontrolpanel` | The Settings app |
| `Microsoft.AccountsControl` | Account/credential dialogs; sign-in breaks |
| `Microsoft.AAD.BrokerPlugin` | Entra/Azure AD & Microsoft account sign-in |
| `Microsoft.Win32WebViewHost` | Hosts embedded web content in system dialogs |
| `Microsoft.CredDialogHost` | UAC/credential prompts |
| `Microsoft.LockApp` | The lock screen |

## 2. Frameworks & runtimes (never remove)

```
Microsoft.UI.Xaml.*
Microsoft.VCLibs.*
Microsoft.NET.Native.Runtime.*
Microsoft.NET.Native.Framework.*
Microsoft.Services.Store.Engagement
Microsoft.WindowsAppRuntime.*
Microsoft.Windows.CbsPreview_cw5n1h2txyewy
```

**Why:** these are shared dependencies. Removing `Microsoft.VCLibs.140.00`
silently breaks dozens of unrelated apps with a generic "this app can't open"
error that is extremely hard to diagnose. They also cost almost no disk space.

## 3. Shell & experience packages

```
Microsoft.Windows.ShellExperienceHost        # Action Center, taskbar flyouts
Microsoft.Windows.StartMenuExperienceHost    # The Start Menu itself
Microsoft.Windows.Search                     # Search host
Microsoft.Windows.CloudExperienceHost        # OOBE, account linking, MDM enrolment
Microsoft.Windows.NarratorShell              # Accessibility — never remove
```

Removing any of these gives you a black Start Menu, a dead taskbar, or an
un-loggable-into machine. Recovery usually requires an in-place repair install.

## 4. Input & language packages

```
Microsoft.Windows.LanguageComponents*
Microsoft.LanguageExperiencePack*
```

Protected unconditionally by the substring guard. Removing the wrong language
pack can leave you with a partially-English UI and a broken input method. If
you genuinely want to remove a language, do it through
**Settings > Time & language > Language & region**, which handles it safely.

## 5. Substring guard — any package containing

| Fragment | Reason |
|---|---|
| `Framework` | Shared dependency |
| `Runtime` | Shared dependency |
| `VCLibs` | Visual C++ UWP runtime |
| `UI.Xaml` | WinUI — used by Store, Settings, Terminal |
| `AppRuntime` | Windows App SDK |
| `Native.Framework` / `Native.Runtime` | .NET Native |
| `LanguageExperiencePack` | Localization |
| `DirectX` | Graphics runtime |
| `SecHealth` | Defender UI |
| `ShellExperience` / `StartMenuExperience` | Shell |
| `immersivecontrolpanel` | Settings |
| `DesktopAppInstaller` | winget |
| `cbspreview` | Component servicing |

## 6. Driver-related programs (always DANGER, never auto-removed)

Detected by keyword in `$DriverKeywords`, forced to `DANGER` risk regardless of
the catalog entry, and excluded from `[A] Remove all SAFE items`:

Realtek · Dolby · Bang & Olufsen · Nahimic · Waves MaxxAudio · Conexant ·
Cirrus Logic · Intel Wireless · Qualcomm · Killer · Synaptics · ELAN · Alps ·
Precision Touchpad · Intel Graphics · NVIDIA · AMD Software/Chipset · Radeon ·
Fingerprint/Goodix/Validity · Windows Hello · Intel Management Engine ·
Serial IO · GPIO · Thunderbolt · Card Reader · RealSense

Run `Get-DriverInfo` (or `Scan-Bloat.ps1`) to see what this matched on your PC.

## 7. Things the script will never do

- Disable the **Windows Update** service (`wuauserv`)
- Disable **Windows Defender** (`WinDefend`) — it only ever *enables* it
- Delete a service (it sets `Manual`/`Disabled` instead, which is reversible)
- Remove the **Edge browser** or **WebView2 runtime**
- Uninstall anything matched as driver-related without an explicit `I ACCEPT`
