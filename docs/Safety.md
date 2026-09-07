# Safety, Recovery & Troubleshooting

## The safety model

| Layer | What it does |
|---|---|
| Protected list | Hard refusal on ~30 packages + 15 substring patterns. Checked 3× per item. |
| Risk tagging | Every item is SAFE / REVIEW / DANGER. `[A]` only ever touches SAFE. |
| Driver detection | Any program matching a driver keyword is force-tagged DANGER. |
| Dry run | You always see the exact action list before anything happens. |
| System Restore Point | Mandatory. Created before the first change. |
| Registry export | Affected branches saved to `backups/<timestamp>/` as `.reg` files. |
| Appx snapshot | Full package list saved as JSON so you know exactly what you had. |
| Retry + fallback | 2 retries, then winget fallback, then log and continue — never abort mid-run. |
| Defender handoff | Removing any AV forces Defender back on and verifies it. |
| Validation | 7 post-run checks with specific fix commands for each failure. |

## Before you run it

1. **Save your work.** A reboot is likely at the end.
2. **Move files out of OneDrive** if you plan to remove OneDrive.
3. Know your Microsoft account password — some removals sign apps out.
4. On a work/school PC, check with IT. Policies may fight the script.

## Recovery — in order of severity

### Level 1 · Something small is missing
Reinstall from the Store, or:
```powershell
winget install --id 9WZDNCRFJBMP --source msstore   # example: Microsoft Store
```
Or use the guided menu:
```powershell
.\scripts\Restore-Bloat.ps1
```

### Level 2 · Start Menu / Search / Settings misbehaving
```powershell
# Re-register every built-in app for the current user
Get-AppxPackage -AllUsers | ForEach-Object {
  Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
}
```
Then sign out and back in.

### Level 3 · A tweak or service change caused it
```powershell
.\scripts\Restore-Bloat.ps1     # option 2 — import a registry backup
```
Or manually double-click the `.reg` files in `backups/<timestamp>/`.

### Level 4 · Roll the whole machine back
```powershell
.\scripts\Restore-Bloat.ps1     # option 1
# or: rstrui.exe
```
Pick the restore point named `BloatRemoval <date>`.

### Level 5 · System file damage
```powershell
sfc /scannow
DISM /Online /Cleanup-Image /RestoreHealth
```
Reboot, then re-run `sfc /scannow`.

### Level 6 · Last resort
**Settings > System > Recovery > Fix problems using Windows Update**
(in-place repair install). Keeps your files and apps.

## Troubleshooting

**"Running scripts is disabled on this system"**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

**"Access is denied" / nothing happens**
You are not elevated. Right-click Terminal > *Run as administrator*.

**"Package is in use" / removal fails twice**
Close the app (check the system tray), then re-run. The script retries twice
and then skips — it never leaves a half-removed package.

**Restore point creation fails**
Usually System Protection is off. Enable it:
*Start > "Create a restore point" > Configure > Turn on system protection*,
give it at least 5% disk space. Or run with `-SkipRestorePoint` if you have
another backup (not recommended).

**Antivirus removal leaves fragments**
Consumer AV vendors ship dedicated cleanup tools. Run the vendor tool after
the script, then reboot:
- McAfee: MCPR (Consumer Product Removal Tool)
- Norton: Norton Remove and Reinstall Tool
- Avast/AVG: avastclear / AVG Clear
- Kaspersky: kavremover
- Bitdefender: Bitdefender Uninstall Tool

**Defender won't turn on after removing AV**
Reboot first — most AV drivers only unload at boot. Then:
```powershell
Set-Service WinDefend -StartupType Automatic; Start-Service WinDefend
Set-MpPreference -DisableRealtimeMonitoring $false
```
If it still fails, a leftover AV registered itself with Security Center. Run
the vendor cleanup tool above.

**Bloat came back after a Windows update**
Expected on major feature updates. Re-run the script, and answer **yes** to
"Prevent bloat from returning". See `Prevent-Reprovisioning.md`.

**Widgets/Copilot button still on the taskbar**
Restart Explorer: `Stop-Process -Name explorer -Force` (it relaunches itself).

## Known limitations

- Copilot's implementation changes between builds; on 24H2+ it may reappear as
  a web app after an update.
- Windows.old removal needs ownership changes and is marked REVIEW.
- OEM tools sometimes reinstall themselves via a leftover scheduled task —
  category 7 handles most, but check Task Scheduler if one keeps returning.
- LTSC images contain far less bloat; expect a very short findings list.
