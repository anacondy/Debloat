# Categories Reference

13 categories. Every item carries a risk level:

| Level | Meaning | Included in `[A] all SAFE`? |
|---|---|---|
| 🟢 **SAFE** | No known dependency. Reversible. | Yes |
| 🟡 **REVIEW** | Some users want it. Read the note. | No |
| 🔴 **DANGER** | Can break hardware or major features. Requires typing `I ACCEPT`. | No |

---

## 1 · Microsoft Store Bloat — 🟢 SAFE
**Detect:** `Get-AppxPackage -AllUsers` + `Get-AppxProvisionedPackage -Online`
**Remove:** `Remove-AppxPackage` + `Remove-AppxProvisionedPackage`

Candy Crush (Saga/Soda/Farm Heroes/Bubble Witch), TikTok, Netflix, Spotify,
Disney+, Instagram, Facebook, WhatsApp, Clipchamp, To Do, Bing News/Weather/
Finance/Sports, Solitaire Collection, Mahjong, Roblox, Hidden City, Disney
Magic Kingdoms, FarmVille 2, Royal Revolt, March of Empires, Asphalt, 3D
Builder, 3D Viewer, Mixed Reality Portal, People, Maps, Get Help, Get Started,
Feedback Hub, Office Hub, Skype, Wallet.

🟡 Minecraft, Sticky Notes, Quick Assist (marked REVIEW — people actually use these).

Provisioned packages are removed too, so new user profiles stay clean.

---

## 2 · Windows 11 Modern Bloat — 🟢 SAFE / 🟡 REVIEW
**Detect:** Appx + registry
**Remove:** `Remove-AppxPackage`, registry values

Copilot (`Microsoft.Copilot`, `Windows.Ai.Copilot.Provider`), Cortana
(`Microsoft.549981C3F5F10`), Widgets (`MicrosoftWindows.Client.WebExperience`),
Teams personal (`MicrosoftTeams` / `MSTeams`), Phone Link (`Microsoft.YourPhone`),
Dev Home, Microsoft Family, Power Automate Desktop.

🟡 New Outlook, Windows Backup, OOBE client.

Taskbar buttons are hidden via `ShowCopilotButton` and `TaskbarDa` = 0.
Copilot's packaging changes per build — the script matches by package name, so
it keeps working across renames.

---

## 3 · OEM / Manufacturer Bloat — 🟡 REVIEW / 🔴 DANGER
**Detect:** Uninstall registry keys (fast — avoids the slow, repair-triggering `Win32_Product`)
**Remove:** QuietUninstallString → UninstallString → msiexec → winget

| Vendor | Targets |
|---|---|
| Dell | SupportAssist, Update, Digital Delivery, Optimizer, Customer Connect, Data Vault |
| HP | Support Assistant, JumpStart, Connection Optimizer, System Event Utility, Sure Click, Printer Control |
| Lenovo | Vantage, Service Bridge, System Update, Companion, Now |
| ASUS | MyASUS, GiftBox, Live Update, System Control Interface (🔴 driver shim) |
| Acer | Care Center, Portal, Quick Access |
| MSI | Dragon Center, Creator Center |
| Samsung | Update, Flow |
| Razer | Synapse, Cortex |
| Corsair | iCUE (🟡 controls RGB and fan curves) |

### ⚠️ Driver safety
Any program whose name matches a driver keyword is **force-tagged 🔴 DANGER**
regardless of catalog risk. Covered: audio (Realtek, Dolby, B&O, Nahimic,
Waves, Conexant, Cirrus), Wi-Fi/Bluetooth (Intel, Qualcomm, Killer), touchpad
(Synaptics, ELAN, Alps, Precision), graphics (Intel, NVIDIA, AMD/Radeon),
fingerprint (Goodix, Validity), Windows Hello/IR, chipset (Intel ME, AMD),
Serial IO, GPIO, Thunderbolt, card readers.

Run `Scan-Bloat.ps1` to see exactly what was protected on your machine.

---

## 4 · Free / Trial Antivirus — 🟢 SAFE removal, 🔴 if Defender fails
**Detect:** Uninstall keys, services, processes
**Remove:** vendor silent uninstaller → msiexec → winget

McAfee, Norton, Avast, AVG, Avira, Kaspersky, Webroot, Malwarebytes (🟡),
Bitdefender, ESET (🟡), Trend Micro, Comodo, 360 Total Security, K7, Quick Heal.

**Mandatory handoff** — after any AV removal the script:
1. Clears the `DisableAntiSpyware` policy
2. Sets `WinDefend` to Automatic and starts it
3. `Set-MpPreference -DisableRealtimeMonitoring $false`
4. `Update-MpSignature`
5. Runs a quick scan
6. Prints a **red critical warning** if steps 2–3 failed

---

## 5 · Telemetry & Privacy — 🟢 SAFE
**Services:** DiagTrack → Disabled · dmwappushservice → Disabled ·
RetailDemo → Disabled · DPS → **Manual** · PcaSvc → **Manual** · WerSvc → **Manual**

**Scheduled tasks disabled:** CEIP Consolidator, UsbCeip, Compatibility
Appraiser, ProgramDataUpdater, Autochk\Proxy, Feedback DmClient, WER
QueueReporting.

**Registry:** `AllowTelemetry`=0, advertising ID off, `PublishUserActivities`/
`UploadUserActivities`=0, feedback notifications off, tailored experiences off,
consumer features off.

Note: DPS/WerSvc are set to *Manual*, never Disabled — Windows still needs them
occasionally for diagnostics and crash handling.

---

## 6 · Unnecessary Services — 🟢 SAFE / 🟡 REVIEW

| Service | Action | Note |
|---|---|---|
| Spooler | 🟡 Disabled | **Disables all printing** |
| Fax | 🟢 Disabled | |
| RemoteRegistry | 🟢 Disabled | Security risk anyway |
| WalletService | 🟢 Manual | |
| MapsBroker | 🟢 Disabled | Offline maps |
| TabletInputService | 🟡 Manual | Touch keyboard — keep on laptops/tablets |
| bthserv / BTAGService | 🟡 Manual | Bluetooth |
| wisvc | 🟢 Disabled | Windows Insider |

Services are **disabled, never deleted** — fully reversible via `services.msc`.

---

## 7 · Startup Apps & Scheduled Tasks — 🟢 SAFE / 🟡 REVIEW
**Detect:** HKLM/HKCU `...\CurrentVersion\Run`, `Get-ScheduledTask`

Startup: Adobe updaters, Epic Games, Discord, Teams, Skype · 🟡 Spotify, Steam,
OneDrive (only if you actually use them).
Tasks: Office telemetry, Google Update, Adobe update tasks.

Startup entries are deleted from the Run key (backed up first); tasks are
*disabled*, not unregistered.

---

## 8 · OneDrive — 🟡 REVIEW (opt-in)
Stops the process → runs `OneDriveSetup.exe /uninstall` → removes the Run entry
→ unpins from the File Explorer sidebar (CLSID `System.IsPinnedToNameSpaceTree`=0).

⚠️ **Move your files out of `%USERPROFILE%\OneDrive` first.** Reinstall via
`Restore-Bloat.ps1` option 5.

---

## 9 · Edge Leftovers — 🟡 REVIEW
**Only safe changes:** disable prelaunch, disable startup boost, disable
background mode, delete the desktop shortcut.

🚫 The script does **not** remove Edge or WebView2 — both are required by
Windows components and many third-party apps.

---

## 10 · Cortana & Search — 🟢 SAFE
`BingSearchEnabled`=0, `CortanaConsent`=0, `AllowCortana`=0,
`DisableSearchBoxSuggestions`=1, search highlights off, 🟡 taskbar search box
reduced to an icon.

---

## 11 · Gaming & Xbox — 🟡 REVIEW
Game Bar, Game Overlay, Xbox App, Speech-to-Text Overlay, Xbox TCUI, Game DVR
capture off; Xbox services (XblAuthManager, XblGameSave, XboxNetApiSvc,
XboxGipSvc) → Manual.

🔴 `Microsoft.XboxIdentityProvider` — **many non-Xbox games sign in through
this.** DANGER-tagged.

The script asks up front: *"Do you play games or use Xbox / Game Pass?"* — answer
yes and the whole category is skipped.

---

## 12 · Optional Windows Features — 🟢 SAFE / 🟡 REVIEW / 🔴 DANGER
**Detect:** `Get-WindowsOptionalFeature -Online` (only lists Enabled ones)

🟢 SMB 1.0 (major security risk), PowerShell 2.0 (legacy, bypasses logging),
Telnet Client, TFTP, XPS Services, Fax & Scan, Remote Differential Compression,
Work Folders Client.
🟡 Windows Media Player, Windows Sandbox, Hyper-V.
🔴 Virtual Machine Platform — **WSL2 and Android subsystem need it.**

Availability is edition-dependent; Hyper-V and Sandbox don't exist on Home.
Feature changes always require a reboot.

---

## 13 · Background Space Wasters — 🟢 SAFE / 🟡 REVIEW
Only listed if >1 MB, and the estimated size is shown before removal.

🟢 `%TEMP%`, `Windows\Temp`, Delivery Optimization cache, Minidump, WER
ReportQueue, CBS logs.
🟡 Prefetch (first app launches get slower for a while), `Windows.old`
(needs ownership; frees 10–30 GB but you lose the ability to roll back a
feature update).
