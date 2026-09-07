# Preventing Bloat From Returning

Removing an app is only half the job. Windows re-installs consumer apps through
three separate mechanisms — you have to shut down all three.

| Mechanism | What it does | Fix |
|---|---|---|
| **Provisioned packages** | Baked into the image; installed for every *new* user profile | `Remove-AppxProvisionedPackage` (the script always does this) |
| **Content Delivery Manager** | Silently downloads "suggested" apps in the background | Registry values below |
| **Cloud Content / consumer experiences** | Pushes promotional apps and Start Menu suggestions | Policy values below |

The script does all of this if you answer **yes** to *"Prevent bloat from
returning after Windows updates?"*, or pass `-PreventReprovisioning`.

## The registry changes (all editions, including Home)

```powershell
# 1. Turn off consumer experiences / cloud content
$cc = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
New-Item $cc -Force | Out-Null
Set-ItemProperty $cc DisableWindowsConsumerFeatures      1 -Type DWord
Set-ItemProperty $cc DisableCloudOptimizedContent        1 -Type DWord
Set-ItemProperty $cc DisableConsumerAccountStateContent  1 -Type DWord

# 2. Stop Content Delivery Manager silently installing apps
$cdm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-ItemProperty $cdm SilentInstalledAppsEnabled   0 -Type DWord
Set-ItemProperty $cdm PreInstalledAppsEnabled      0 -Type DWord
Set-ItemProperty $cdm OemPreInstalledAppsEnabled   0 -Type DWord

# 3. Per-user suggestion surfaces (repeat for each user profile)
$u = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
'SilentInstalledAppsEnabled','SystemPaneSuggestionsEnabled','SoftLandingEnabled',
'RotatingLockScreenOverlayEnabled','SubscribedContent-338388Enabled',
'SubscribedContent-338389Enabled','SubscribedContent-353698Enabled',
'ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled',
'PreInstalledAppsEverEnabled' | ForEach-Object {
  Set-ItemProperty $u $_ 0 -Type DWord -Force -EA SilentlyContinue
}

# 4. Stop the Start Menu "recommended" app pushes
$ex = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
New-Item $ex -Force | Out-Null
Set-ItemProperty $ex HideRecommendedSection 1 -Type DWord   # 24H2+, Enterprise/Edu
```

## Group Policy equivalent (Pro / Enterprise / Education)

`gpedit.msc` →
**Computer Configuration > Administrative Templates > Windows Components > Cloud Content**

| Policy | Set to |
|---|---|
| Turn off Microsoft consumer experiences | **Enabled** |
| Turn off cloud optimized content | **Enabled** |
| Turn off cloud consumer account state content | **Enabled** |
| Do not show Windows tips | **Enabled** |
| Turn off all Windows spotlight features (User Config) | **Enabled** |

Then `gpupdate /force`.

## Stop Copilot specifically

```powershell
$cp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
New-Item $cp -Force | Out-Null
Set-ItemProperty $cp TurnOffWindowsCopilot 1 -Type DWord
```

## Stop Widgets specifically

```powershell
$dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
New-Item $dsh -Force | Out-Null
Set-ItemProperty $dsh AllowNewsAndInterests 0 -Type DWord
```

## Stop the new Outlook being pushed

```powershell
$mo = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler_Oobe'
Remove-Item "$mo\OutlookUpdate"    -Force -Recurse -EA SilentlyContinue
Remove-Item "$mo\DevHomeUpdate"    -Force -Recurse -EA SilentlyContinue
```

## What this does NOT stop

⚠️ **Major feature updates** (23H2 → 24H2 → 25H2) install a fresh image. That
can restore provisioned packages and reset some policy values. This is by
design and there is no supported way around it.

**Recommendation:** after every feature update, re-run:

```powershell
.\scripts\Remove-Bloat.ps1 -SafeOnly
```

It takes about a minute and skips anything already gone.

## Reversing all of this

```powershell
Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'      -Recurse -Force -EA SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'    -Recurse -Force -EA SilentlyContinue
Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                       -Recurse -Force -EA SilentlyContinue
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' SilentInstalledAppsEnabled 1
gpupdate /force
```

Or import the `.reg` files from `backups/<timestamp>/` via
`Restore-Bloat.ps1` option 2.
