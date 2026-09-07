#!/usr/bin/env bash
# bloatdata.sh - protected list, driver keywords and the bloat catalog.
# Mirrors scripts/helpers/BloatData.ps1. Keep the two in sync.

# --- "DO NOT TOUCH" protected packages (prefix match) --------------------
PROTECTED_EXACT=(
    'Microsoft.WindowsStore'
    'Microsoft.StorePurchaseApp'
    'Microsoft.WindowsCalculator'
    'Microsoft.WindowsNotepad'
    'Microsoft.Paint'
    'Microsoft.ScreenSketch'
    'Microsoft.WindowsTerminal'
    'Microsoft.Windows.Photos'
    'Microsoft.DesktopAppInstaller'
    'Microsoft.SecHealthUI'
    'Windows.immersivecontrolpanel'
    'Microsoft.AccountsControl'
    'Microsoft.AAD.BrokerPlugin'
    'Microsoft.Windows.ShellExperienceHost'
    'Microsoft.Windows.StartMenuExperienceHost'
    'Microsoft.Windows.Search'
    'Microsoft.Windows.CloudExperienceHost'
    'Microsoft.Windows.NarratorShell'
    'Microsoft.Services.Store.Engagement'
    'Microsoft.Windows.CbsPreview'
    'Microsoft.Windows.LanguageComponents'
    'Microsoft.WindowsAppRuntime'
    'Microsoft.Win32WebViewHost'
    'Microsoft.CredDialogHost'
    'Microsoft.LockApp'
    'Microsoft.Windows.SecureAssessmentBrowser'
    'Microsoft.WindowsStore.Engagement'
)

# --- Substring guards ----------------------------------------------------
PROTECTED_CONTAINS=(
    'Framework' 'Runtime' 'VCLibs' 'UI.Xaml' 'AppRuntime'
    'Native.Framework' 'Native.Runtime' 'LanguageExperiencePack'
    'WindowsAppRuntime' 'DirectX' 'NET.Native' 'SecHealth'
    'ShellExperience' 'StartMenuExperience' 'immersivecontrolpanel'
    'DesktopAppInstaller' 'cbspreview'
)

# --- Driver keywords (always DANGER) -------------------------------------
DRIVER_KEYWORDS=(
    'Realtek' 'Dolby' 'Bang & Olufsen' 'Nahimic' 'Waves MaxxAudio'
    'Conexant' 'Cirrus Logic' 'Intel(R) Wireless' 'Qualcomm' 'Killer'
    'Bluetooth Driver' 'Wi-Fi Driver' 'Synaptics' 'ELAN'
    'Precision Touchpad' 'Alps' 'Intel(R) Graphics' 'NVIDIA'
    'AMD Software' 'AMD Chipset' 'Radeon' 'Fingerprint' 'Goodix'
    'Validity' 'Windows Hello' 'Management Engine' 'Serial IO' 'GPIO'
    'Thunderbolt' 'Card Reader' 'RealSense' 'Chipset Device Software'
    'Audio Driver' 'Camera Driver'
)

# Case-insensitive lowercase helper
_lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# is_protected NAME -> 0 (true) if the package must never be removed
is_protected() {
    local name lname p lp
    name="$1"
    lname=$(_lc "$name")
    for p in "${PROTECTED_EXACT[@]}"; do
        lp=$(_lc "$p")
        [[ "$lname" == "$lp"* ]] && return 0
    done
    for p in "${PROTECTED_CONTAINS[@]}"; do
        lp=$(_lc "$p")
        [[ "$lname" == *"$lp"* ]] && return 0
    done
    return 1
}

# is_driver_related NAME -> 0 (true) if driver/hardware software
is_driver_related() {
    local name lname k lk
    name="$1"
    lname=$(_lc "$name")
    for k in "${DRIVER_KEYWORDS[@]}"; do
        lk=$(_lc "$k")
        [[ "$lname" == *"$lk"* ]] && return 0
    done
    return 1
}

# --- Category titles -----------------------------------------------------
# shellcheck disable=SC2034  # consumed by remove.sh and entry points
declare -A CAT_TITLE=(
    [1]='Microsoft Store Bloat'
    [2]='Windows 11 Modern Bloat (Copilot, Widgets, Teams...)'
    [3]='OEM / Manufacturer Bloat'
    [4]='Free / Trial Antivirus & Security Suites'
    [5]='Telemetry & Privacy'
    [6]='Unnecessary Windows Services'
    [7]='Startup Apps & Scheduled Tasks'
    [8]='OneDrive Integration (optional)'
    [9]='Edge Leftovers (shortcuts / prelaunch only)'
    [10]='Cortana & Search Leftovers'
    [11]='Gaming & Xbox Components (REVIEW)'
    [12]='Optional Windows Features'
    [13]='Background Space Wasters'
)

# --- Catalog -------------------------------------------------------------
# Format per line:  CATKEY|NAME|RISK|TYPE|EXTRA|NOTE
# TYPE: Appx Win32 Service Task Startup Registry Feature Cleanup OneDrive Shortcut
# EXTRA: services -> target startup mode; registry -> HIVE\PATH::VALUENAME::DATA;
#        cleanup -> path template
BLOAT_CATALOG=(
# --- 1. Microsoft Store bloat
'1|king.com.CandyCrushSaga|SAFE|Appx||'
'1|king.com.CandyCrushSodaSaga|SAFE|Appx||'
'1|king.com.BubbleWitch3Saga|SAFE|Appx||'
'1|king.com.FarmHeroesSaga|SAFE|Appx||'
'1|BytedancePte.Ltd.TikTok|SAFE|Appx||'
'1|4DF9E0F8.Netflix|SAFE|Appx||'
'1|SpotifyAB.SpotifyMusic|SAFE|Appx||'
'1|Disney.37853FC22B2CE|SAFE|Appx||'
'1|Facebook.InstagramBeta|SAFE|Appx||'
'1|Facebook.Facebook|SAFE|Appx||'
'1|5319275A.WhatsAppDesktop|SAFE|Appx||'
'1|Clipchamp.Clipchamp|SAFE|Appx||'
'1|Microsoft.Todos|SAFE|Appx||'
'1|Microsoft.BingNews|SAFE|Appx||'
'1|Microsoft.BingWeather|SAFE|Appx||'
'1|Microsoft.BingFinance|SAFE|Appx||'
'1|Microsoft.BingSports|SAFE|Appx||'
'1|Microsoft.MicrosoftSolitaireCollection|SAFE|Appx||'
'1|Microsoft.MicrosoftMahjong|SAFE|Appx||'
'1|Microsoft.MinecraftUWP|REVIEW|Appx||Some users play this'
'1|ROBLOXCORPORATION.ROBLOX|SAFE|Appx||'
'1|HiddenCity*|SAFE|Appx||'
'1|DisneyMagicKingdoms*|SAFE|Appx||'
'1|*FarmVille*|SAFE|Appx||'
'1|*RoyalRevolt*|SAFE|Appx||'
'1|*MarchofEmpires*|SAFE|Appx||'
'1|*Asphalt*|SAFE|Appx||'
'1|Microsoft.3DBuilder|SAFE|Appx||'
'1|Microsoft.Microsoft3DViewer|SAFE|Appx||'
'1|Microsoft.MixedReality.Portal|SAFE|Appx||'
'1|Microsoft.People|SAFE|Appx||'
'1|Microsoft.WindowsMaps|SAFE|Appx||'
'1|Microsoft.GetHelp|SAFE|Appx||'
'1|Microsoft.Getstarted|SAFE|Appx||'
'1|Microsoft.WindowsFeedbackHub|SAFE|Appx||'
'1|Microsoft.MicrosoftOfficeHub|SAFE|Appx||'
'1|Microsoft.SkypeApp|SAFE|Appx||'
'1|Microsoft.Wallet|SAFE|Appx||'
'1|Microsoft.MicrosoftStickyNotes|REVIEW|Appx||People store notes here'
'1|MicrosoftCorporationII.QuickAssist|REVIEW|Appx||Used for remote support'
# --- 2. Windows 11 modern bloat
'2|Microsoft.Copilot|SAFE|Appx||'
'2|Microsoft.Windows.Ai.Copilot.Provider|SAFE|Appx||'
'2|Microsoft.549981C3F5F10|SAFE|Appx||Cortana'
'2|MicrosoftWindows.Client.WebExperience|SAFE|Appx||Widgets'
'2|MicrosoftTeams|SAFE|Appx||'
'2|MSTeams|SAFE|Appx||'
'2|Microsoft.YourPhone|SAFE|Appx||Phone Link'
'2|Microsoft.Windows.DevHome|SAFE|Appx||'
'2|Microsoft.OutlookForWindows|REVIEW|Appx||New Outlook'
'2|MicrosoftCorporationII.MicrosoftFamily|SAFE|Appx||'
'2|Microsoft.PowerAutomateDesktop|SAFE|Appx||'
'2|Microsoft.WindowsBackup|REVIEW|Appx||'
'2|MicrosoftWindows.Client.OOBE|REVIEW|Appx||'
'2|ShowCopilotButton|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced::ShowCopilotButton::0|Hides Copilot taskbar button'
'2|TaskbarDa|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced::TaskbarDa::0|Hides Widgets taskbar button'
# --- 3. OEM bloat
'3|Dell SupportAssist|REVIEW|Win32||'
'3|Dell Update|REVIEW|Win32||'
'3|Dell Digital Delivery|SAFE|Win32||'
'3|Dell Optimizer|REVIEW|Win32||'
'3|Dell Customer Connect|SAFE|Win32||'
'3|Dell Data Vault|REVIEW|Win32||'
'3|HP Support Assistant|REVIEW|Win32||'
'3|HP JumpStart|SAFE|Win32||'
'3|HP Connection Optimizer|SAFE|Win32||'
'3|HP System Event Utility|REVIEW|Win32||'
'3|HP Sure Click|REVIEW|Win32||'
'3|AD2F1837.HPPrinterControl|REVIEW|Appx||'
'3|Lenovo Vantage|REVIEW|Win32||'
'3|Lenovo Service Bridge|SAFE|Win32||'
'3|Lenovo System Update|REVIEW|Win32||'
'3|Lenovo Now|SAFE|Win32||'
'3|E046963F.LenovoCompanion|REVIEW|Appx||'
'3|E046963F.LenovoSettingsforEnterprise|REVIEW|Appx||'
'3|MyASUS|REVIEW|Win32||'
'3|ASUS GiftBox|SAFE|Win32||'
'3|ASUS Live Update|REVIEW|Win32||'
'3|ASUS System Control Interface|DANGER|Win32||Driver shim - hardware keys may stop working'
'3|Acer Care Center|REVIEW|Win32||'
'3|Acer Portal|SAFE|Win32||'
'3|Acer Quick Access|REVIEW|Win32||'
'3|MSI Dragon Center|REVIEW|Win32||'
'3|MSI Creator Center|REVIEW|Win32||'
'3|Samsung Update|REVIEW|Win32||'
'3|Samsung Flow|SAFE|Win32||'
'3|Razer Synapse|REVIEW|Win32||'
'3|Razer Cortex|SAFE|Win32||'
'3|iCUE|REVIEW|Win32||Controls RGB and fan curves'
# --- 4. Antivirus
'4|McAfee*|SAFE|Win32||'
'4|Norton*|SAFE|Win32||'
'4|Avast*|SAFE|Win32||'
'4|AVG *|SAFE|Win32||'
'4|Avira*|SAFE|Win32||'
'4|Kaspersky*|SAFE|Win32||'
'4|Webroot*|SAFE|Win32||'
'4|Malwarebytes*|REVIEW|Win32||You may have paid for this'
'4|Bitdefender*|SAFE|Win32||'
'4|ESET*|REVIEW|Win32||You may have paid for this'
'4|Trend Micro*|SAFE|Win32||'
'4|Comodo*|SAFE|Win32||'
'4|360 Total Security*|SAFE|Win32||'
'4|Quick Heal*|SAFE|Win32||'
'4|K7 *|SAFE|Win32||'
# --- 5. Telemetry and privacy
'5|DiagTrack|SAFE|Service|disabled|Connected User Experiences and Telemetry'
'5|dmwappushservice|SAFE|Service|disabled|'
'5|DPS|SAFE|Service|demand|Diagnostic Policy - set to Manual not Disabled'
'5|PcaSvc|SAFE|Service|demand|Program Compatibility Assistant'
'5|RetailDemo|SAFE|Service|disabled|'
'5|WerSvc|SAFE|Service|demand|Windows Error Reporting'
'5|\Microsoft\Windows\Customer Experience Improvement Program\Consolidator|SAFE|Task||'
'5|\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip|SAFE|Task||'
'5|\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser|SAFE|Task||'
'5|\Microsoft\Windows\Application Experience\ProgramDataUpdater|SAFE|Task||'
'5|\Microsoft\Windows\Autochk\Proxy|SAFE|Task||'
'5|\Microsoft\Windows\Feedback\Siuf\DmClient|SAFE|Task||'
'5|\Microsoft\Windows\Windows Error Reporting\QueueReporting|SAFE|Task||'
'5|AllowTelemetry|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection::AllowTelemetry::0|'
'5|Enabled|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo::Enabled::0|Advertising ID'
'5|PublishUserActivities|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Windows\System::PublishUserActivities::0|'
'5|UploadUserActivities|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Windows\System::UploadUserActivities::0|'
'5|DoNotShowFeedbackNotifications|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection::DoNotShowFeedbackNotifications::1|'
'5|DisableTailoredExperiencesWithDiagnosticData|SAFE|Registry|HKCU\Software\Policies\Microsoft\Windows\CloudContent::DisableTailoredExperiencesWithDiagnosticData::1|'
'5|DisableWindowsConsumerFeatures|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent::DisableWindowsConsumerFeatures::1|'
# --- 6. Services
'6|Spooler|REVIEW|Service|disabled|DISABLES ALL PRINTING'
'6|Fax|SAFE|Service|disabled|'
'6|RemoteRegistry|SAFE|Service|disabled|Security risk anyway'
'6|WalletService|SAFE|Service|demand|'
'6|MapsBroker|SAFE|Service|disabled|Offline maps'
'6|TabletInputService|REVIEW|Service|demand|Touch keyboard - keep on laptops'
'6|bthserv|REVIEW|Service|demand|Bluetooth'
'6|BTAGService|REVIEW|Service|demand|Bluetooth audio'
'6|wisvc|SAFE|Service|disabled|Windows Insider'
# --- 7. Startup and tasks
'7|*Adobe*Updater*|SAFE|Startup||'
'7|*Spotify*|REVIEW|Startup||'
'7|*Steam*|REVIEW|Startup||'
'7|*EpicGames*|SAFE|Startup||'
'7|*Discord*|SAFE|Startup||'
'7|*Teams*|SAFE|Startup||'
'7|*OneDrive*|REVIEW|Startup||'
'7|*Skype*|SAFE|Startup||'
'7|\Microsoft\Office\OfficeTelemetry*|SAFE|Task||'
'7|GoogleUpdateTask*|SAFE|Task||'
'7|Adobe*Update*|SAFE|Task||'
# --- 8. OneDrive
'8|OneDrive|REVIEW|OneDrive||Move files out of the OneDrive folder first'
# --- 9. Edge leftovers
'9|AllowPrelaunch|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main::AllowPrelaunch::0|'
'9|StartupBoostEnabled|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Edge::StartupBoostEnabled::0|'
'9|BackgroundModeEnabled|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Edge::BackgroundModeEnabled::0|'
'9|EdgeDesktopShortcut|SAFE|Shortcut||Removes the desktop shortcut only'
# --- 10. Cortana and search
'10|BingSearchEnabled|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\Search::BingSearchEnabled::0|'
'10|CortanaConsent|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\Search::CortanaConsent::0|'
'10|AllowCortana|SAFE|Registry|HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search::AllowCortana::0|'
'10|DisableSearchBoxSuggestions|SAFE|Registry|HKCU\Software\Policies\Microsoft\Windows\Explorer::DisableSearchBoxSuggestions::1|'
'10|EnableDynamicContentInWSB|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings::EnableDynamicContentInWSB::0|Search highlights'
'10|SearchboxTaskbarMode|REVIEW|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\Search::SearchboxTaskbarMode::1|Shrinks search box to an icon'
# --- 11. Gaming and Xbox
'11|Microsoft.XboxGamingOverlay|REVIEW|Appx||'
'11|Microsoft.XboxGameOverlay|REVIEW|Appx||'
'11|Microsoft.XboxApp|REVIEW|Appx||'
'11|Microsoft.XboxSpeechToTextOverlay|REVIEW|Appx||'
'11|Microsoft.Xbox.TCUI|REVIEW|Appx||'
'11|Microsoft.XboxIdentityProvider|DANGER|Appx||Many non-Xbox games sign in through this'
'11|XblAuthManager|REVIEW|Service|demand|'
'11|XblGameSave|REVIEW|Service|demand|'
'11|XboxNetApiSvc|REVIEW|Service|demand|'
'11|XboxGipSvc|REVIEW|Service|demand|'
'11|AppCaptureEnabled|SAFE|Registry|HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR::AppCaptureEnabled::0|Disables Game DVR capture'
# --- 12. Optional features
'12|SMB1Protocol|SAFE|Feature||Major security risk'
'12|MicrosoftWindowsPowerShellV2|SAFE|Feature||Legacy - bypasses logging'
'12|MicrosoftWindowsPowerShellV2Root|SAFE|Feature||Legacy - bypasses logging'
'12|TelnetClient|SAFE|Feature||'
'12|TFTP|SAFE|Feature||'
'12|Printing-XPSServices-Features|SAFE|Feature||'
'12|FaxServicesClientPackage|SAFE|Feature||'
'12|MSRDC-Infrastructure|SAFE|Feature||'
'12|WorkFolders-Client|SAFE|Feature||'
'12|WindowsMediaPlayer|REVIEW|Feature||'
'12|Containers-DisposableClientVM|REVIEW|Feature||Windows Sandbox'
'12|Microsoft-Hyper-V-All|REVIEW|Feature||'
'12|VirtualMachinePlatform|DANGER|Feature||WSL2 and Android subsystem need this'
# --- 13. Space wasters
'13|UserTemp|SAFE|Cleanup|%TEMP%|'
'13|WindowsTemp|SAFE|Cleanup|%SystemRoot%\Temp|'
'13|DeliveryOptimization|SAFE|Cleanup|%SystemRoot%\SoftwareDistribution\DeliveryOptimization|'
'13|Minidump|SAFE|Cleanup|%SystemRoot%\Minidump|'
'13|WERReports|SAFE|Cleanup|%ProgramData%\Microsoft\Windows\WER\ReportQueue|'
'13|CBSLogs|SAFE|Cleanup|%SystemRoot%\Logs\CBS|'
'13|Prefetch|REVIEW|Cleanup|%SystemRoot%\Prefetch|First app launches get slower for a while'
'13|WindowsOld|REVIEW|Cleanup|%SystemDrive%\Windows.old|Removes feature-update rollback ability'
)

# catalog_count -> number of entries
catalog_count() { printf '%s' "${#BLOAT_CATALOG[@]}"; }

# catalog_field LINE INDEX (1-based) -> field value
catalog_field() {
    local line="$1" idx="$2"
    printf '%s' "$line" | cut -d'|' -f"$idx"
}
