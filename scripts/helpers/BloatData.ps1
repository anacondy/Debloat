# BloatData.ps1 - Central catalog: protected list, categories, targets.
# Dot-source this file. Defines $Global:BloatCatalog and $Global:Protected*.

# -------------------------------------------------------------
# "DO NOT TOUCH" PROTECTED PACKAGES
# -------------------------------------------------------------
$Global:ProtectedExact = @(
    'Microsoft.WindowsStore'
    'Microsoft.StorePurchaseApp'
    'Microsoft.WindowsCalculator'
    'Microsoft.WindowsNotepad'
    'Microsoft.Paint'
    'Microsoft.ScreenSketch'
    'Microsoft.WindowsTerminal'
    'Microsoft.Windows.Photos'
    'Microsoft.DesktopAppInstaller'        # winget
    'Microsoft.SecHealthUI'                # Windows Security UI
    'Windows.immersivecontrolpanel'        # Settings
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

# Substring guards - any package whose name contains one of these is protected.
$Global:ProtectedContains = @(
    'Framework'
    'Runtime'
    'VCLibs'
    'UI.Xaml'
    'AppRuntime'
    'Native.Framework'
    'Native.Runtime'
    'LanguageExperiencePack'
    'WindowsAppRuntime'
    'DirectX'
    'NET.Native'
    'SecHealth'
    'ShellExperience'
    'StartMenuExperience'
    'immersivecontrolpanel'
    'DesktopAppInstaller'
    'cbspreview'
)

function Test-Protected {
    <#
      .SYNOPSIS Returns $true if the package name must never be removed.
    #>
    param([Parameter(Mandatory)][string]$Name)
    foreach ($p in $Global:ProtectedExact) {
        if ($Name -like "$p*") { return $true }
    }
    foreach ($c in $Global:ProtectedContains) {
        if ($Name -like "*$c*") { return $true }
    }
    return $false
}

# -------------------------------------------------------------
# DRIVER-RELATED PROGRAMS (always DANGER - never auto-remove)
# -------------------------------------------------------------
$Global:DriverKeywords = @(
    'Realtek','Dolby','Bang & Olufsen','Nahimic','Waves MaxxAudio','Conexant','Cirrus Logic'
    'Intel(R) Wireless','Qualcomm','Killer','Bluetooth Driver','Wi-Fi Driver'
    'Synaptics','ELAN','Precision Touchpad','Alps'
    'Intel(R) Graphics','NVIDIA','AMD Software','AMD Chipset','Radeon'
    'Fingerprint','Goodix','Validity','Windows Hello'
    'Management Engine','Serial IO','GPIO','Thunderbolt','Card Reader','RealSense'
    'Chipset Device Software','Audio Driver','Camera Driver'
)

function Test-DriverRelated {
    param([Parameter(Mandatory)][string]$Name)
    foreach ($k in $Global:DriverKeywords) {
        if ($Name -like "*$k*") { return $true }
    }
    return $false
}

# -------------------------------------------------------------
# CATEGORY CATALOG
# Each item: Name (match pattern), Risk (SAFE/REVIEW/DANGER), Type
# Types: Appx | Win32 | Service | Task | Registry | Feature | Cleanup
# -------------------------------------------------------------
$Global:BloatCatalog = [ordered]@{

  '1' = @{ Title='Microsoft Store Bloat'; Risk='SAFE'; Items=@(
      @{N='king.com.CandyCrushSaga';Risk='SAFE';T='Appx'}
      @{N='king.com.CandyCrushSodaSaga';Risk='SAFE';T='Appx'}
      @{N='king.com.BubbleWitch3Saga';Risk='SAFE';T='Appx'}
      @{N='king.com.FarmHeroesSaga';Risk='SAFE';T='Appx'}
      @{N='BytedancePte.Ltd.TikTok';Risk='SAFE';T='Appx'}
      @{N='4DF9E0F8.Netflix';Risk='SAFE';T='Appx'}
      @{N='SpotifyAB.SpotifyMusic';Risk='SAFE';T='Appx'}
      @{N='Disney.37853FC22B2CE';Risk='SAFE';T='Appx'}
      @{N='Facebook.InstagramBeta';Risk='SAFE';T='Appx'}
      @{N='Facebook.Facebook';Risk='SAFE';T='Appx'}
      @{N='5319275A.WhatsAppDesktop';Risk='SAFE';T='Appx'}
      @{N='Clipchamp.Clipchamp';Risk='SAFE';T='Appx'}
      @{N='Microsoft.Todos';Risk='SAFE';T='Appx'}
      @{N='Microsoft.BingNews';Risk='SAFE';T='Appx'}
      @{N='Microsoft.BingWeather';Risk='SAFE';T='Appx'}
      @{N='Microsoft.BingFinance';Risk='SAFE';T='Appx'}
      @{N='Microsoft.BingSports';Risk='SAFE';T='Appx'}
      @{N='Microsoft.MicrosoftSolitaireCollection';Risk='SAFE';T='Appx'}
      @{N='Microsoft.MicrosoftMahjong';Risk='SAFE';T='Appx'}
      @{N='Microsoft.MinecraftUWP';Risk='REVIEW';T='Appx'}
      @{N='ROBLOXCORPORATION.ROBLOX';Risk='SAFE';T='Appx'}
      @{N='HiddenCity*';Risk='SAFE';T='Appx'}
      @{N='DisneyMagicKingdoms*';Risk='SAFE';T='Appx'}
      @{N='*FarmVille*';Risk='SAFE';T='Appx'}
      @{N='*RoyalRevolt*';Risk='SAFE';T='Appx'}
      @{N='*MarchofEmpires*';Risk='SAFE';T='Appx'}
      @{N='*Asphalt*';Risk='SAFE';T='Appx'}
      @{N='Microsoft.3DBuilder';Risk='SAFE';T='Appx'}
      @{N='Microsoft.Microsoft3DViewer';Risk='SAFE';T='Appx'}
      @{N='Microsoft.MixedReality.Portal';Risk='SAFE';T='Appx'}
      @{N='Microsoft.People';Risk='SAFE';T='Appx'}
      @{N='Microsoft.WindowsMaps';Risk='SAFE';T='Appx'}
      @{N='Microsoft.GetHelp';Risk='SAFE';T='Appx'}
      @{N='Microsoft.Getstarted';Risk='SAFE';T='Appx'}
      @{N='Microsoft.WindowsFeedbackHub';Risk='SAFE';T='Appx'}
      @{N='Microsoft.MicrosoftOfficeHub';Risk='SAFE';T='Appx'}
      @{N='Microsoft.SkypeApp';Risk='SAFE';T='Appx'}
      @{N='Microsoft.Wallet';Risk='SAFE';T='Appx'}
      @{N='Microsoft.MicrosoftStickyNotes';Risk='REVIEW';T='Appx'}
      @{N='MicrosoftCorporationII.QuickAssist';Risk='REVIEW';T='Appx'}
  )}

  '2' = @{ Title='Windows 11 Modern Bloat (Copilot, Widgets, Teams...)'; Risk='SAFE'; Items=@(
      @{N='Microsoft.Copilot';Risk='SAFE';T='Appx'}
      @{N='Microsoft.Windows.Ai.Copilot.Provider';Risk='SAFE';T='Appx'}
      @{N='Microsoft.549981C3F5F10';Risk='SAFE';T='Appx'}   # Cortana
      @{N='MicrosoftWindows.Client.WebExperience';Risk='SAFE';T='Appx'}  # Widgets
      @{N='MicrosoftTeams';Risk='SAFE';T='Appx'}
      @{N='MSTeams';Risk='SAFE';T='Appx'}
      @{N='Microsoft.YourPhone';Risk='SAFE';T='Appx'}
      @{N='Microsoft.Windows.DevHome';Risk='SAFE';T='Appx'}
      @{N='Microsoft.OutlookForWindows';Risk='REVIEW';T='Appx'}
      @{N='MicrosoftWindows.Client.OOBE';Risk='REVIEW';T='Appx'}
      @{N='MicrosoftCorporationII.MicrosoftFamily';Risk='SAFE';T='Appx'}
      @{N='Microsoft.PowerAutomateDesktop';Risk='SAFE';T='Appx'}
      @{N='Microsoft.WindowsBackup';Risk='REVIEW';T='Appx'}
      @{N='ShowCopilotButton';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Value=0}
      @{N='TaskbarDa';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';Value=0} # Widgets button
  )}

  '3' = @{ Title='OEM / Manufacturer Bloat'; Risk='REVIEW'; Items=@(
      @{N='Dell SupportAssist';Risk='REVIEW';T='Win32'}
      @{N='Dell Update';Risk='REVIEW';T='Win32'}
      @{N='Dell Digital Delivery';Risk='SAFE';T='Win32'}
      @{N='Dell Optimizer';Risk='REVIEW';T='Win32'}
      @{N='Dell Customer Connect';Risk='SAFE';T='Win32'}
      @{N='Dell Data Vault';Risk='REVIEW';T='Win32'}
      @{N='HP Support Assistant';Risk='REVIEW';T='Win32'}
      @{N='HP JumpStart';Risk='SAFE';T='Win32'}
      @{N='HP Connection Optimizer';Risk='SAFE';T='Win32'}
      @{N='HP System Event Utility';Risk='REVIEW';T='Win32'}
      @{N='HP Sure Click';Risk='REVIEW';T='Win32'}
      @{N='AD2F1837.HPPrinterControl';Risk='REVIEW';T='Appx'}
      @{N='Lenovo Vantage';Risk='REVIEW';T='Win32'}
      @{N='Lenovo Service Bridge';Risk='SAFE';T='Win32'}
      @{N='Lenovo System Update';Risk='REVIEW';T='Win32'}
      @{N='E046963F.LenovoCompanion';Risk='REVIEW';T='Appx'}
      @{N='E046963F.LenovoSettingsforEnterprise';Risk='REVIEW';T='Appx'}
      @{N='Lenovo Now';Risk='SAFE';T='Win32'}
      @{N='MyASUS';Risk='REVIEW';T='Win32'}
      @{N='ASUS GiftBox';Risk='SAFE';T='Win32'}
      @{N='ASUS Live Update';Risk='REVIEW';T='Win32'}
      @{N='ASUS System Control Interface';Risk='DANGER';T='Win32'}
      @{N='Acer Care Center';Risk='REVIEW';T='Win32'}
      @{N='Acer Portal';Risk='SAFE';T='Win32'}
      @{N='Acer Quick Access';Risk='REVIEW';T='Win32'}
      @{N='MSI Dragon Center';Risk='REVIEW';T='Win32'}
      @{N='MSI Creator Center';Risk='REVIEW';T='Win32'}
      @{N='Samsung Update';Risk='REVIEW';T='Win32'}
      @{N='Samsung Flow';Risk='SAFE';T='Win32'}
      @{N='Razer Synapse';Risk='REVIEW';T='Win32'}
      @{N='Razer Cortex';Risk='SAFE';T='Win32'}
      @{N='iCUE';Risk='REVIEW';T='Win32'}
  )}

  '4' = @{ Title='Free / Trial Antivirus & Security Suites'; Risk='SAFE'; Items=@(
      @{N='McAfee*';Risk='SAFE';T='Win32'}
      @{N='Norton*';Risk='SAFE';T='Win32'}
      @{N='Avast*';Risk='SAFE';T='Win32'}
      @{N='AVG *';Risk='SAFE';T='Win32'}
      @{N='Avira*';Risk='SAFE';T='Win32'}
      @{N='Kaspersky*';Risk='SAFE';T='Win32'}
      @{N='Webroot*';Risk='SAFE';T='Win32'}
      @{N='Malwarebytes*';Risk='REVIEW';T='Win32'}
      @{N='Bitdefender*';Risk='SAFE';T='Win32'}
      @{N='ESET*';Risk='REVIEW';T='Win32'}
      @{N='Trend Micro*';Risk='SAFE';T='Win32'}
      @{N='Comodo*';Risk='SAFE';T='Win32'}
      @{N='360 Total Security*';Risk='SAFE';T='Win32'}
      @{N='K7 *';Risk='SAFE';T='Win32'}
      @{N='Quick Heal*';Risk='SAFE';T='Win32'}
  )}

  '5' = @{ Title='Telemetry & Privacy'; Risk='SAFE'; Items=@(
      @{N='DiagTrack';Risk='SAFE';T='Service';Target='Disabled'}
      @{N='dmwappushservice';Risk='SAFE';T='Service';Target='Disabled'}
      @{N='DPS';Risk='SAFE';T='Service';Target='Manual'}
      @{N='PcaSvc';Risk='SAFE';T='Service';Target='Manual'}
      @{N='RetailDemo';Risk='SAFE';T='Service';Target='Disabled'}
      @{N='WerSvc';Risk='SAFE';T='Service';Target='Manual'}
      @{N='\Microsoft\Windows\Customer Experience Improvement Program\Consolidator';Risk='SAFE';T='Task'}
      @{N='\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip';Risk='SAFE';T='Task'}
      @{N='\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser';Risk='SAFE';T='Task'}
      @{N='\Microsoft\Windows\Application Experience\ProgramDataUpdater';Risk='SAFE';T='Task'}
      @{N='\Microsoft\Windows\Autochk\Proxy';Risk='SAFE';T='Task'}
      @{N='\Microsoft\Windows\Feedback\Siuf\DmClient';Risk='SAFE';T='Task'}
      @{N='\Microsoft\Windows\Windows Error Reporting\QueueReporting';Risk='SAFE';T='Task'}
      @{N='AllowTelemetry';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';Value=0}
      @{N='Enabled';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo';Value=0}
      @{N='PublishUserActivities';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';Value=0}
      @{N='UploadUserActivities';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';Value=0}
      @{N='DoNotShowFeedbackNotifications';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';Value=1}
      @{N='DisableTailoredExperiencesWithDiagnosticData';Risk='SAFE';T='Registry';Path='HKCU:\Software\Policies\Microsoft\Windows\CloudContent';Value=1}
      @{N='DisableWindowsConsumerFeatures';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent';Value=1}
  )}

  '6' = @{ Title='Unnecessary Windows Services'; Risk='REVIEW'; Items=@(
      @{N='Spooler';Risk='REVIEW';T='Service';Target='Disabled';Note='Disables printing'}
      @{N='Fax';Risk='SAFE';T='Service';Target='Disabled'}
      @{N='RemoteRegistry';Risk='SAFE';T='Service';Target='Disabled'}
      @{N='WalletService';Risk='SAFE';T='Service';Target='Manual'}
      @{N='MapsBroker';Risk='SAFE';T='Service';Target='Disabled'}
      @{N='TabletInputService';Risk='REVIEW';T='Service';Target='Manual';Note='Touch keyboard'}
      @{N='bthserv';Risk='REVIEW';T='Service';Target='Manual';Note='Bluetooth'}
      @{N='BTAGService';Risk='REVIEW';T='Service';Target='Manual'}
      @{N='wisvc';Risk='SAFE';T='Service';Target='Disabled';Note='Windows Insider'}
  )}

  '7' = @{ Title='Startup Apps & Scheduled Tasks'; Risk='SAFE'; Items=@(
      @{N='*Adobe*Updater*';Risk='SAFE';T='Startup'}
      @{N='*Spotify*';Risk='REVIEW';T='Startup'}
      @{N='*Steam*';Risk='REVIEW';T='Startup'}
      @{N='*EpicGames*';Risk='SAFE';T='Startup'}
      @{N='*Discord*';Risk='SAFE';T='Startup'}
      @{N='*Teams*';Risk='SAFE';T='Startup'}
      @{N='*OneDrive*';Risk='REVIEW';T='Startup'}
      @{N='*Skype*';Risk='SAFE';T='Startup'}
      @{N='\Microsoft\Office\OfficeTelemetry*';Risk='SAFE';T='Task'}
      @{N='GoogleUpdateTask*';Risk='SAFE';T='Task'}
      @{N='Adobe*Update*';Risk='SAFE';T='Task'}
  )}

  '8' = @{ Title='OneDrive Integration (optional)'; Risk='REVIEW'; Items=@(
      @{N='OneDrive';Risk='REVIEW';T='OneDrive'}
  )}

  '9' = @{ Title='Edge Leftovers (shortcuts / prelaunch only)'; Risk='REVIEW'; Items=@(
      @{N='AllowPrelaunch';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main';Value=0}
      @{N='StartupBoostEnabled';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge';Value=0}
      @{N='BackgroundModeEnabled';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge';Value=0}
      @{N='EdgeDesktopShortcut';Risk='SAFE';T='Shortcut'}
  )}

  '10' = @{ Title='Cortana & Search Leftovers'; Risk='SAFE'; Items=@(
      @{N='BingSearchEnabled';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search';Value=0}
      @{N='CortanaConsent';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search';Value=0}
      @{N='AllowCortana';Risk='SAFE';T='Registry';Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search';Value=0}
      @{N='DisableSearchBoxSuggestions';Risk='SAFE';T='Registry';Path='HKCU:\Software\Policies\Microsoft\Windows\Explorer';Value=1}
      @{N='EnableDynamicContentInWSB';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings';Value=0}
      @{N='SearchboxTaskbarMode';Risk='REVIEW';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search';Value=1}
  )}

  '11' = @{ Title='Gaming & Xbox Components (REVIEW)'; Risk='REVIEW'; Items=@(
      @{N='Microsoft.XboxGamingOverlay';Risk='REVIEW';T='Appx'}
      @{N='Microsoft.XboxGameOverlay';Risk='REVIEW';T='Appx'}
      @{N='Microsoft.XboxApp';Risk='REVIEW';T='Appx'}
      @{N='Microsoft.XboxSpeechToTextOverlay';Risk='REVIEW';T='Appx'}
      @{N='Microsoft.Xbox.TCUI';Risk='REVIEW';T='Appx'}
      @{N='Microsoft.XboxIdentityProvider';Risk='DANGER';T='Appx';Note='Many games require this'}
      @{N='XboxGipSvc';Risk='REVIEW';T='Service';Target='Manual'}
      @{N='XblAuthManager';Risk='REVIEW';T='Service';Target='Manual'}
      @{N='XblGameSave';Risk='REVIEW';T='Service';Target='Manual'}
      @{N='XboxNetApiSvc';Risk='REVIEW';T='Service';Target='Manual'}
      @{N='AppCaptureEnabled';Risk='SAFE';T='Registry';Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Value=0}
  )}

  '12' = @{ Title='Optional Windows Features'; Risk='REVIEW'; Items=@(
      @{N='SMB1Protocol';Risk='SAFE';T='Feature';Note='Major security risk'}
      @{N='MicrosoftWindowsPowerShellV2';Risk='SAFE';T='Feature'}
      @{N='MicrosoftWindowsPowerShellV2Root';Risk='SAFE';T='Feature'}
      @{N='TelnetClient';Risk='SAFE';T='Feature'}
      @{N='TFTP';Risk='SAFE';T='Feature'}
      @{N='Printing-XPSServices-Features';Risk='SAFE';T='Feature'}
      @{N='FaxServicesClientPackage';Risk='SAFE';T='Feature'}
      @{N='MSRDC-Infrastructure';Risk='SAFE';T='Feature'}
      @{N='WorkFolders-Client';Risk='SAFE';T='Feature'}
      @{N='WindowsMediaPlayer';Risk='REVIEW';T='Feature'}
      @{N='Containers-DisposableClientVM';Risk='REVIEW';T='Feature';Note='Windows Sandbox'}
      @{N='Microsoft-Hyper-V-All';Risk='REVIEW';T='Feature'}
      @{N='VirtualMachinePlatform';Risk='DANGER';T='Feature';Note='WSL2 needs this'}
  )}

  '13' = @{ Title='Background Space Wasters'; Risk='SAFE'; Items=@(
      @{N='UserTemp';Risk='SAFE';T='Cleanup';Path=$env:TEMP}
      @{N='WindowsTemp';Risk='SAFE';T='Cleanup';Path="$env:SystemRoot\Temp"}
      @{N='DeliveryOptimization';Risk='SAFE';T='Cleanup';Path="$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"}
      @{N='Minidump';Risk='SAFE';T='Cleanup';Path="$env:SystemRoot\Minidump"}
      @{N='WERReports';Risk='SAFE';T='Cleanup';Path="$env:ProgramData\Microsoft\Windows\WER\ReportQueue"}
      @{N='CBSLogs';Risk='SAFE';T='Cleanup';Path="$env:SystemRoot\Logs\CBS"}
      @{N='Prefetch';Risk='REVIEW';T='Cleanup';Path="$env:SystemRoot\Prefetch"}
      @{N='WindowsOld';Risk='REVIEW';T='Cleanup';Path="$env:SystemDrive\Windows.old"}
  )}
}
