@ECHO OFF

REM This script creates a custom ISO to install Windows 11 without a Windows
REM account and additional services and features removed
REM
REM Author: Stefan Schulte <stschulte@posteo.de>
REM Date  : 2023-11-27
REM
REM This script has to be executed in an environment that comes with
REM Windows ADK.
REM
REM This script makes a lot of assumptions that are true in my specific
REM environment so you *have* to adapt this
REM
REM You most definetly want to modify the Autounattend.xml file and the
REM username that will be baked into the image

SETLOCAL enableDelayedExpansion

SET IMAGEFACTORY_WORK_DIR=%~dp0work
SET IMAGEFACTORY_MNT=%IMAGEFACTORY_WORK_DIR%\mnt
SET IMAGEFACTORY_ORIGINAL_ISO=NOTFOUND
SET IMAGEFACTORY_ORIGINAL_MSU=NOTFOUND
SET IMAGEFACTORY_ZIP=%ProgramFiles%\7-Zip\7z.exe
SET IMAGEFACTORY_DRIVERS=work\driver\amdafd.inf_amd64_98939332ba1b458a\amdafd.inf work\driver\cyucmclient.inf_amd64_3d5e258995978aa0\cyucmclient.inf work\driver\lgsusb.inf_amd64_c6a29e4cd588cf6a\lgsusb.inf work\driver\smbusamd.inf_amd64_246caabd058be11f\smbusamd.inf work\driver\tbthostcontroller.inf_amd64_90f6a13df0927823\tbthostcontroller.inf work\driver\tbthostcontrollerhsacomponent.inf_amd64_d31d2cc1c9ebc4c5\tbthostcontrollerhsacomponent.inf work\driver\e2f.inf_amd64_2d5cb0c750512550\e2f.inf work\driver\amdgpio2.inf_amd64_26fd146b41c45ce2\amdgpio2.inf work\driver\asusswc.inf_amd64_a4fdd01ce4b4de03\asusswc.inf work\driver\ctxhda.inf_amd64_1239ba03e9051498\ctxhda.inf work\driver\asussci2.inf_amd64_f2eed2fae3b45a67\asussci2.inf work\driver\amdxe.inf_amd64_0acaa805f9dce5db\amdxe.inf work\driver\amdfendr.inf_amd64_94e2f75a4412cfa7\amdfendr.inf work\driver\amdocl.inf_amd64_72b6f6149721cc42\amdocl.inf work\driver\amdgpio3.inf_amd64_f03ace476a8fec30\amdgpio3.inf work\driver\amdwin-u0400566.inf_amd64_9a17dbbd825a9442\amdwin-u0400566.inf work\driver\amdpcidev.inf_amd64_2dbed7efd5f2b448\amdpcidev.inf work\driver\amdpsp.inf_amd64_3d8eba6178a9a15e\amdpsp.inf work\driver\u0400566.inf_amd64_5e4d397bddb6fe15\u0400566.inf work\driver\atihdwt6.inf_amd64_e054ad64864d19d3\atihdwt6.inf %IMAGEFACTORY_WORK_DIR%\driver\dpumdf.inf_amd64_ff7b1b8d2f1dbf38\dpumdf.inf %IMAGEFACTORY_WORK_DIR%\driver\e_wf1iue.inf_amd64_eac672f51dbb1f66\e_wf1iue.inf
SET IMAGEFACTORY_GOOGLE_CHROME_SETUP=googlechromestandaloneenterprise64.msi
SET IMAGEFACTORY_GOOGLE_CHROME_POLICY=policy_templates.zip
SET IMAGEFACTORY_EDGE_POLICY=MicrosoftEdgePolicyTemplates.cab
SET IMAGEFACTORY_ZIP_SETUP=7z2403-x64.msi
SET IMAGEFACTORY_SUMATRAPDF=SumatraPDF-3.5.2-64-install.exe

@ECHO Validating environment
@ECHO ======================

WHERE OSCDIMG >nul 2>nul
IF %ERRORLEVEL% NEQ 0 GOTO :err_no_oscdimg
@ECHO * OSCDIMG found

DISM /English /? >nul
IF %ERRORLEVEL% NEQ 0 GOTO :err_no_dism
@ECHO * DISM found and working

WHERE LGPO >nul 2>nul
IF %ERRORLEVEL% NEQ 0 GOTO :err_no_lgpo
@ECHO * LGPO found

IF NOT EXIST %IMAGEFACTORY_GOOGLE_CHROME_SETUP% GOTO :err_no_chrome_setup
@ECHO * Google Chrome Setup found: %IMAGEFACTORY_GOOGLE_CHROME_SETUP%

IF NOT EXIST %IMAGEFACTORY_GOOGLE_CHROME_POLICY% GOTO :err_no_chrome_policy
@ECHO * Google Chrome Group policies found: %IMAGEFACTORY_GOOGLE_CHROME_POLICY%

IF NOT EXIST %IMAGEFACTORY_EDGE_POLICY% GOTO :err_no_edge_policy
@ECHO * Edge Policy cabinet file found: MicrosoftEdgePolicyTemplates.cab

IF NOT EXIST "%IMAGEFACTORY_ZIP%" GOTO :err_no_zip
@ECHO * 7zip found: %IMAGEFACTORY_ZIP%

IF NOT EXIST "%IMAGEFACTORY_ZIP_SETUP%" GOTO :err_no_zip_setup
@ECHO * 7 Zip installation found: %IMAGEFACTORY_ZIP_SETUP%

IF NOT EXIST "%IMAGEFACTORY_SUMATRAPDF%" GOTO :err_no_sumatrapdf
@ECHO * SumatraPDF install found: %IMAGEFACTORY_SUMATRAPDF%

FOR %%x in (Win11*.iso) DO SET IMAGEFACTORY_ORIGINAL_ISO=%%x
IF %IMAGEFACTORY_ORIGINAL_ISO% == NOTFOUND GOTO :err_no_image
@ECHO * Windows Image found: %IMAGEFACTORY_ORIGINAL_ISO%

FOR %%x in (windows11.0-kb5037771*.msu) DO SET IMAGEFACTORY_ORIGINAL_MSU=%%x
IF %IMAGEFACTORY_ORIGINAL_MSU% == NOTFOUND GOTO :err_no_patch
@ECHO * KB5037771 found: %IMAGEFACTORY_ORIGINAL_MSU%

FOR %%x IN (%IMAGEFACTORY_ZIP_SETUP% %IMAGEFACTORY_GOOGLE_CHROME_SETUP% %IMAGEFACTORY_SUMATRAPDF%) DO (
  SET IMAGEFACTORY_ADS=%%x
  dir /R !IMAGEFACTORY_ADS!|findstr Zone.Identifier >nul
  IF !ERRORLEVEL! EQU 0 GOTO :err_ads
)

IF EXIST %IMAGEFACTORY_WORK_DIR% GOTO :err_work_already_exists
@ECHO * temporary directory "%IMAGEFACTORY_WORK_DIR%" does not exist yet

findstr /L ABCD1-EF2G3-4HI5J-KL6MN-OP7QR Autounattend.xml >nul 2>nul
IF %ERRORLEVEL% EQU 0 GOTO :err_product_key_not_changed

findstr /L User001 Autounattend.xml >nul 2>nul
IF %ERRORLEVEL% EQU 0 GOTO :err_user_not_changed

MD %IMAGEFACTORY_WORK_DIR%

@ECHO.
@ECHO Prepare Directories and drivers
@ECHO ===============================
@ECHO.

@ECHO Export driver from current system
MD %IMAGEFACTORY_WORK_DIR%\driver
dism /English /Quiet /Online /Export-Driver /Destination:%IMAGEFACTORY_WORK_DIR%\driver

FOR %%x IN (%IMAGEFACTORY_DRIVERS%) DO (
  IF NOT EXIST "%%x" (
    SET IMAGEFACTORY_MISSING_DRIVER=%%x
    GOTO :err_driver_not_found
  )
)

IF "%IMAGEFACTORY_DRIVERS%" == "" (
  SET DISM_ADD_DRIVER_CMD=@ECHO No drivers to add
) ELSE (
  SET DISM_ADD_DRIVER_CMD=dism /English /Image:%IMAGEFACTORY_MNT% /Add-Driver
  FOR %%x IN (%IMAGEFACTORY_DRIVERS%) DO SET DISM_ADD_DRIVER_CMD=!DISM_ADD_DRIVER_CMD! /Driver:%%x
)

@ECHO.
@ECHO Mount the Windows Image
@ECHO =======================
@ECHO.

@ECHO Extract install.wim from original ISO
MD %IMAGEFACTORY_WORK_DIR%\sources
"%IMAGEFACTORY_ZIP%" e -o%IMAGEFACTORY_WORK_DIR%\sources "%IMAGEFACTORY_ORIGINAL_ISO%" sources\install.wim >nul

@ECHO Export Windows 11 Pro Image
dism /English /Export-Image /SourceImageFile:%IMAGEFACTORY_WORK_DIR%\sources\install.wim /SourceIndex:5 /DestinationImageFile:%IMAGEFACTORY_WORK_DIR%\install.wim /Compress:max

@ECHO Mount Windows 11 Pro Image
MD %IMAGEFACTORY_MNT%
dism /English /Mount-Wim /WimFile:%IMAGEFACTORY_WORK_DIR%\install.wim /Index:1 /MountDir:%IMAGEFACTORY_MNT%

@ECHO.
@ECHO In case you abort this script or it fails before the end, you have to unmount
@ECHO the image again. You can do this by running
@ECHO.
@ECHO     dism /Unmount-Wim /MountDir:%IMAGEFACTORY_MNT% /Discard
@ECHO.

@ECHO.
@ECHO Adding Updates
@ECHO ==============
@ECHO.

@ECHO Installing KB5037771 (this can take ~30 minutes)

dism /English /Image:%IMAGEFACTORY_MNT% /Add-Package /PackagePath:"%IMAGEFACTORY_ORIGINAL_MSU%"

@ECHO.
@ECHO Cleanup: Remove packages
@ECHO ========================
@ECHO.

@ECHO Removing package Clipchamp.Clipchamp
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt

@ECHO Removing package Microsoft.549981C3F5F10
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.549981C3F5F10_3.2204.14815.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.BingNews
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.BingNews_4.2.27001.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.BingWeather
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.BingWeather_4.53.33420.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.GamingApp
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.GamingApp_2021.427.138.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.GetHelp
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.GetHelp_10.2201.421.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.Getstarted
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Getstarted_2021.2204.1.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.MicrosoftOfficeHub
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.MicrosoftOfficeHub_18.2204.1141.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.MicrosoftStickyNotes
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.MicrosoftStickyNotes_4.2.2.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.People
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.People_2020.901.1724.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.PowerAutomateDesktop
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.PowerAutomateDesktop_10.0.3735.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.Todos
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Todos_2.54.42772.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.WindowsAlarms
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsAlarms_2022.2202.24.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.WindowsCamera
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsCamera_2022.2201.4.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package microsoft.windowscommunicationsapps
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:microsoft.windowscommunicationsapps_16005.14326.20544.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.WindowsFeedbackHub
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsFeedbackHub_2022.106.2230.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.WindowsMaps
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsMaps_2022.2202.6.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.WindowsSoundRecorder
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsSoundRecorder_2021.2103.28.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.Xbox.TCUI
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Xbox.TCUI_1.23.28004.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.XboxGameOverlay
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxGameOverlay_1.47.2385.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.XboxGamingOverlay
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxGamingOverlay_2.622.3232.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.XboxIdentityProvider
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxIdentityProvider_12.50.6001.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.XboxSpeechToTextOverlay
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxSpeechToTextOverlay_1.17.29001.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.YourPhone
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.YourPhone_1.22022.147.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.ZuneMusic
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.ZuneMusic_11.2202.46.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package Microsoft.ZuneVideo
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:Microsoft.ZuneVideo_2019.22020.10021.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package MicrosoftCorporationII.QuickAssist
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:MicrosoftCorporationII.QuickAssist_2022.414.1758.0_neutral_~_8wekyb3d8bbwe

@ECHO Removing package MicrosoftWindows.Client.WebExperience
dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-ProvisionedAppxPackage /PackageName:MicrosoftWindows.Client.WebExperience_421.20070.195.0_neutral_~_cw5n1h2txyewy

@ECHO.
@ECHO Cleanup: Removing capabilities
@ECHO ==============================
@ECHO.
@ECHO Remove capability Hello.Face.20134~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Broadcom.Bcmpciedhd63~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63al~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63a~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwbw02~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwew00~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwew01~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwlv64~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwns64~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwsw00~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw02~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw04~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw06~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw08~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw10~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Marvel.Mrvlpcie8897~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Qualcomm.Athw8x~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Qualcomm.Athwnx~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Qualcomm.Qcamain10x64~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Ralink.Netr28x~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl8187se~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl8192se~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl819xp~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl85n64~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtwlane01~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtwlane13~~~~0.0.1.0
@ECHO Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtwlane~~~~0.0.1.0
@ECHO Remove capability App.StepsRecorder~~~~0.0.1.0

dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Remove-Capability /CapabilityName:Hello.Face.20134~~~~0.0.1.0 /CapabilityName:App.StepsRecorder~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Broadcom.Bcmpciedhd63~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63al~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63a~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwbw02~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwew00~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwew01~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwlv64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwns64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwsw00~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw02~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw04~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw06~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw08~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw10~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Marvel.Mrvlpcie8897~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Qualcomm.Athw8x~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Qualcomm.Athwnx~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Qualcomm.Qcamain10x64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Ralink.Netr28x~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl8187se~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl8192se~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl819xp~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl85n64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtwlane01~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtwlane13~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtwlane~~~~0.0.1.0

@ECHO.
@ECHO Cleanup: Disable Features
@ECHO ==============================
@ECHO.
@ECHO Remove feature MSRDC-Infrastructure
@ECHO Remove feature SearchEngine-Client-Package
@ECHO Remove feature WorkFolders-Client

dism /English /Quiet /Image:%IMAGEFACTORY_MNT% /Disable-Feature /FeatureName:MSRDC-Infrastructure /FeatureName:SearchEngine-Client-Package /FeatureName:WorkFolders-Client

@ECHO.
@ECHO Customize: Add drivers
@ECHO ======================
@ECHO.
@ECHO Add drivers for High Definition Audio Bus
@ECHO Add drivers for Cypress UCM-Client-Peripherie-Treiber
@ECHO Add drivers for Logitech Download Assistant
@ECHO Add drivers for AMD SMBus
@ECHO Add drivers for Thunderbolt(TM) Controller - 1137
@ECHO Add drivers for Thunderbolt(TM) HSA Component
@ECHO Add drivers for Intel(R) Ethernet Controller (3) I225-V
@ECHO Add drivers for AMD GPIO Controller
@ECHO Add drivers for ASUS App Component
@ECHO Add drivers for Sound BlasterX AE-5 Plus
@ECHO Add drivers for ASUS System Control Interface v3
@ECHO Add drivers for AMD Link Controller Emulation
@ECHO Add drivers for AMD Crash Defender
@ECHO Add drivers for AMD-OpenCL User Mode Driver
@ECHO Add drivers for AMD GPIO Controller
@ECHO Add drivers for AMD-Windows Support Components
@ECHO Add drivers for AMD PCI
@ECHO Add drivers for AMD PSP 11.0 Device
@ECHO Add drivers for AMD Radeon RX 5700 XT
@ECHO Add drivers for AMD High Definition Audio Device
@ECHO Add drivers for REINER SCT cyberJack e-com(a)/e-com plus/Secoder USB
@ECHO Add drivers for EPSON WF-2540 Series
%DISM_ADD_DRIVER_CMD%
@ECHO Installing drivers ... DONE

@ECHO.
@ECHO Customize registry settings
@ECHO ===========================
@ECHO.

@ECHO Loading SYSTEM registry
reg load HKLM\OFFLINE %IMAGEFACTORY_MNT%\Windows\System32\config\SYSTEM >nul

@ECHO Setting time to UTC
reg add HKLM\OFFLINE\ControlSet001\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_QWORD /d 1 >nul

@ECHO Disable MS Edge First Run Experience
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "StartupBoostEnabled" /t REG_DWORD /d 0 /f >nul

@ECHO Disable MS Edge SmartScreen
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /t REG_DWORD /d 0 /f >nul

@ECHO Disable MS Edge SmartScreen DNS
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenDnsRequestsEnabled" /t REG_DWORD /d 0 /f >nul

@ECHO Disable Typeosquatting Checker
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "TyposquattingCheckerEnabled" /t REG_DWORD /d 0 /f >nul

@ECHO Disable keep apps running after close
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "BackgroundModeEnabled" /t REG_DWORD /d 0 /f >nul

@ECHO Configure DNT (Do Not Track) for Edge
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "ConfigureDoNotTrack" /t REG_DWORD /d 1 /f >nul

@ECHO Do not ask users to switch to Edge
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "DefaultBrowserSettingsCampaignEnabled" /t REG_DWORD /d 0 /f >nul

@ECHO Disable Cloud Sync
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "SyncDisabled" /t REG_DWORD /d 1 /f >nul

@ECHO Disable first run experience
reg add "HKLM\OFFLINE\SOFTWARE\Policies\Microsoft\Edge" /v "HideFirstRunExperience" /t REG_DWORD /d 1 /f >nul

@ECHO Disable Defender Cloud
reg add "HKLM\OFFLINE\SOFTWARE\Microsoft\Windows Defender\Spynet" /v SpyNetReporting /t REG_DWORD /d 0 /f >nul

@ECHO Disable Defender Submit Samples to Microsoft
reg add "HKLM\OFFLINE\SOFTWARE\Microsoft\Windows Defender\Spynet" /v SubmitSamplesConsent /t REG_DWORD /d 0 >nul

@ECHO Change AllJoyn Router Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\AJRouter /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change AMD Crash Defender Service from Automatic to Disabled
reg add "HKLM\OFFLINE\ControlSet001\Services\AMD Crash Defender Service" /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS App Service from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\AsusAppService /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS Link Near from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ASUSLinkNear /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS Link Remote from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ASUSLinkRemote /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS Optimization from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ASUSOptimization /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS Software Manager from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ASUSSoftwareManager /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS Switch from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ASUSSwitch /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change ASUS System Diagnosis from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ASUSSystemDiagnosis /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Cellular Time from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\autotimesvc /v START /t REG_DWORD /d 4 /f > nul

REM @ECHO Change Capability Access Manager Service from Manual to Disabled
REM reg add HKLM\OFFLINE\ControlSet001\Services\camsvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Microsoft Cloud Identity Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\cloudidsvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Microsoft (R) Diagnostics Hub Standard Collector Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\diagnosticshub.standardcollector.service /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Connected User Experiences and Telemetry from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\DiagTrack /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Device Management Wireless Application Protocol (WAP) Push message Routing Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\dmwappushservice /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Wired AutoConfig from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\dot3svc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Camera Frame Server from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\FrameServer /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Camera Frame Server Monitor from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\FrameServerMonitor /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change GameInput Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\GameInputSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change HV Host Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\HvHost /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Mobile Hotspot Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\icssvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Geolocation Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\lfsvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change TCP/IP NetBIOS Helper from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\lmhosts /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Downloaded Maps Manager from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\MapsBroker /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Mixed Reality OpenXR Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\MixedRealityOpenXRSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Microsoft iSCSI Initiator Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\MSiSCSI /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Natural Authentication from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\NaturalAuthentication /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Program Compatibility Assistant Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\PcaSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Perception Simulation Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\perceptionsimulation /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Phone Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\PhoneSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows PushToInstall Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\PushToInstall /v START /t REG_DWORD /d 4 /f > nul

REM @ECHO Change Remote Access Auto Connection Manager from Manual to Disabled
REM reg add HKLM\OFFLINE\ControlSet001\Services\RasAuto /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Retail Demo Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\RetailDemo /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Smart Card Removal Policy from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\SCPolicySvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Payments and NFC/SE Manager from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\SEMgrSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Internet Connection Sharing (ICS) from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\SharedAccess /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Spatial Data Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\SharedRealitySvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Shell Hardware Detection from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\ShellHWDetection /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Microsoft Storage Spaces SMP from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\smphost /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Telephony from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\TapiSrv /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Storage Tiers Management from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\TieringEngineService /v START /t REG_DWORD /d 4 /f > nul

REM @ECHO Change Web Account Manager from Manual to Disabled
REM reg add HKLM\OFFLINE\ControlSet001\Services\TokenBroker /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Guest Service Interface from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmicguestinterface /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Heartbeat Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmicheartbeat /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Data Exchange Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmickvpexchange /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Remote Desktop Virtualization Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmicrdv /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Guest Shutdown Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmicshutdown /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Time Synchronization Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmictimesync /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V PowerShell Direct Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmicvmsession /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Hyper-V Volume Shadow Copy Requestor from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\vmicvss /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change WalletService from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\WalletService /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Biometric Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\WbioSrvc /v START /t REG_DWORD /d 4 /f > nul

REM @ECHO Change Windows Connection Manager from Automatic to Disabled
REM reg add HKLM\OFFLINE\ControlSet001\Services\Wcmsvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Connect Now - Config Registrar from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\wcncsvc /v START /t REG_DWORD /d 4 /f > nul

REM @ECHO Change Wi-Fi Direct Services Connection Manager Service from Manual to Disabled
REM reg add HKLM\OFFLINE\ControlSet001\Services\WFDSConMgrSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Insider Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\wisvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change WLAN AutoConfig from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\WlanSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Microsoft Account Sign-in Assistant from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\wlidsvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Media Player Network Sharing Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\WMPNetworkSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Parental Controls from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\WpcMonSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Windows Search from Automatic to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\WSearch /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Xbox Live Auth Manager from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\XblAuthManager /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Xbox Live Game Save from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\XblGameSave /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Xbox Accessory Management Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\XboxGipSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Change Xbox Live Networking Service from Manual to Disabled
reg add HKLM\OFFLINE\ControlSet001\Services\XboxNetApiSvc /v START /t REG_DWORD /d 4 /f > nul

@ECHO Unloading SYSTEM registry
reg unload HKLM\OFFLINE >nul

@ECHO.
@ECHO Customize registry settings for new users
@ECHO =========================================
@ECHO.

@ECHO Load registry
reg load HKLM\OFFLINE %IMAGEFACTORY_MNT%\Users\Default\NTUSER.DAT >nul

@ECHO Disable content delivery manager
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v FeatureManagementEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SlideshowEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul

@ECHO Disable typing insights
reg add "HKLM\OFFLINE\Software\Microsoft\input\Settings" /v InsightsEnabled /t REG_DWORD /d 0 /f >nul

@ECHO Disable show text suggestions when typing on the physical keyboard
reg add "HKLM\OFFLINE\Software\Microsoft\input\Settings" /v EnableHwkbTextPrediction /t REG_DWORD /d 0 /f >nul

@ECHO Disable multilingual text suggestions
reg add "HKLM\OFFLINE\Software\Microsoft\input\Settings" /v MultilingualEnabled /t REG_DWORD /d 0 /f >nul

@ECHO Disable autocorrect misspelled words
reg add "HKLM\OFFLINE\Software\Microsoft\TabletTip\1.7" /v EnableAutocorrection /t REG_DWORD /d 0 /f >nul

@ECHO Disable Highlight misspelled words
reg add "HKLM\OFFLINE\Software\Microsoft\TabletTip\1.7" /v EnableSpellchecking /t REG_DWORD /d 0 /f >nul

@ECHO Enable Search in Taskbar
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d 2 /f >nul

@ECHO Show file extensions
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f >nul

@ECHO Show hidden files
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f >nul

@ECHO Disable Chat Icon in Taskbar
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f >nul

@ECHO Disable Widgets
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f >nul

@ECHO Disable SmartScreen
reg add "HKLM\OFFLINE\SOFTWARE\Microsoft\Edge\SmartScreenEnabled" /ve /t REG_DWORD /d 0 /f >nul

@ECHO Disable Windows personalized ADs
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul

@ECHO Disable Communication with unpaired devices
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync" /v Deny /t REG_SZ /d Deny /f >nul

@ECHO Disable autostarting closed apps
reg add "HKLM\OFFLINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v RestartApps /t REG_DWORD /d 0 /f >nul

@ECHO Disable OneDrive Setup on login
reg delete "HKLM\OFFLINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f >nul

@ECHO Unload registry
reg unload HKLM\OFFLINE >nul

REM Unfortunately OneDrive will still install, so rename it here. Unfortunately a simple
REM rename does not work, since even Administrators do not have full permissions on the file.
REM We first change the owner from TrustedInstaller to the Administrators Group (SID S-1-5-32-544).
REM We then change the Access Control Lists (ACLs) to give the Administrator Group full permissions
REM on the file. We can then savely rename and restore the original permissions again.

@ECHO Rename Windows\System32\OneDriveSetup.exe to Windows\System32\OneDriveSetup.backup
takeown /F %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.exe /A >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.exe /grant *S-1-5-32-544:F >nul
move %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.exe %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup /setowner "NT SERVICE\TrustedInstaller" >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup /grant:r *S-1-5-32-544:RX >nul

@ECHO Adding Windows\System32\OneDriveSetup.backup.txt for instructions to reenable
echo If you want to renable OneDriveSetup, open a console as administrator and > %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo execute the following commands in order. You do not have to switch to a specific >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo directory for this to work. >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo. >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo takeown /F C:\Windows\System32\OneDriveSetup.backup /A >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo icacls C:\Windows\System32\OneDriveSetup.backup /grant *S-1-5-32-544:F >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo move C:\Windows\System32\OneDriveSetup.backup C:\Windows\System32\OneDriveSetup.exe  >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo icacls C:\Windows\System32\OneDriveSetup.exe /setowner "NT SERVICE\TrustedInstaller" >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt
echo icacls C:\Windows\System32\OneDriveSetup.exe /grant:r *S-1-5-32-544:RX  >> %IMAGEFACTORY_MNT%\Windows\System32\OneDriveSetup.backup.txt

@ECHO.
@ECHO Adding additional software
@ECHO ==========================
@ECHO.
@ECHO Adding Google Chrome
copy %IMAGEFACTORY_GOOGLE_CHROME_SETUP% %IMAGEFACTORY_MNT%\Windows\System32\googlechromestandaloneenterprise64.msi >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\googlechromestandaloneenterprise64.msi /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\googlechromestandaloneenterprise64.msi /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Adding 7zip
copy %IMAGEFACTORY_ZIP_SETUP% %IMAGEFACTORY_MNT%\Windows\System32\7z2403-x64.msi >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\7z2403-x64.msi /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\7z2403-x64.msi /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Adding SumatraPDF
copy %IMAGEFACTORY_SUMATRAPDF% %IMAGEFACTORY_MNT%\Windows\System32\SumatraPDF-3.5.2-64-install.exe >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\SumatraPDF-3.5.2-64-install.exe /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\System32\SumatraPDF-3.5.2-64-install.exe /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO.
@ECHO Import local group policies
@ECHO ===========================
@ECHO.

MD %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\Machine
MD %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\User

@ECHO Extract Google Chrome Policy definitions
MD %IMAGEFACTORY_WORK_DIR%\policy\chrome
"%IMAGEFACTORY_ZIP%" x -o%IMAGEFACTORY_WORK_DIR%\policy\chrome %IMAGEFACTORY_GOOGLE_CHROME_POLICY% windows\admx >nul

@ECHO Extract Microsoft Edge Policy definitions
MD %IMAGEFACTORY_WORK_DIR%\policy\edge
expand -R "%IMAGEFACTORY_EDGE_POLICY%" -F:microsoftedgepolicytemplates.zip %IMAGEFACTORY_WORK_DIR% >nul
"%IMAGEFACTORY_ZIP%" x -o%IMAGEFACTORY_WORK_DIR%\policy\edge %IMAGEFACTORY_WORK_DIR%\microsoftedgepolicytemplates.zip windows\admx >nul

@ECHO Copy policy definitions into image
xcopy /F /S /H %IMAGEFACTORY_WORK_DIR%\policy\chrome\windows\admx %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions >nul
xcopy /F /S /H %IMAGEFACTORY_WORK_DIR%\policy\edge\windows\admx %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions >nul

@ECHO Fixing ACLs on  policy definitions: google.admx
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\google.admx /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\google.admx /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Fixing ACLs on  policy definitions: google.adml
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*google.adml /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 /T >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*google.adml /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F /T >nul

@ECHO Fixing ACLs on  policy definitions: chrome.admx
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\chrome.admx /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\chrome.admx /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Fixing ACLs on  policy definitions: chrome.adml
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*chrome.adml /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 /T >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*chrome.adml /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F /T >nul

@ECHO Fixing ACLs on  policy definitions: msedge.admx
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\msedge.admx /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\msedge.admx /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Fixing ACLs on  policy definitions: msedge.adml
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*msedge.adml /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 /T >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*msedge.adml /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F /T >nul

@ECHO Fixing ACLs on  policy definitions: msedgeupdate.admx
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\msedgeupdate.admx /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\msedgeupdate.admx /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Fixing ACLs on  policy definitions: msedgeupdate.adml
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*msedgeupdate.adml /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 /T >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*msedgeupdate.adml /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F /T >nul

@ECHO Fixing ACLs on  policy definitions: msedgewebview2.admx
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\msedgewebview2.admx /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\msedgewebview2.admx /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F >nul

@ECHO Fixing ACLs on  policy definitions: msedgewebview2.adml
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*msedgewebview2.adml /setowner *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464 /T >nul
icacls %IMAGEFACTORY_MNT%\Windows\PolicyDefinitions\*msedgewebview2.adml /inheritance:r /grant:r *S-1-15-2-2:RX /grant:r *S-1-15-2-1:RX /grant:r *S-1-5-32-545:RX /grant:r *S-1-5-18:RX /grant:r *S-1-5-32-544:RX /grant:r *S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464:F /T >nul

REM we first create a gpt.ini file. Otherwise *some* group policies don't seem to get applied correctly
REM The version will be
REM 0000 0000 0000 0001 0000 0000 0000 0001
REM to set machine and user version to 1
REM

echo [General] > %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\gpt.ini
echo Version=65537 >> %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\gpt.ini
echo gPCMachineExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{D02B1F72-3407-48AE-BA88-E8213C6761F1}] >> %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\gpt.ini
echo gPCUserExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{D02B1F73-3407-48AE-BA88-E8213C6761F1}] >> %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\gpt.ini

LGPO.exe /r lgpo.m.txt /w %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\Machine\Registry.pol
LGPO.exe /r lgpo.u.txt /w %IMAGEFACTORY_MNT%\Windows\System32\GroupPolicy\User\Registry.pol

@ECHO.
@ECHO Add our transport truck directory
@ECHO =================================
@ECHO.

IF EXIST TransportTruck xcopy /S /E /H /I TransportTruck %IMAGEFACTORY_MNT%\TransportTruck

@ECHO.
@ECHO Finalizing Image
@ECHO ================
@ECHO.

@ECHO Analyze Component Store
dism /English /Cleanup-Image /Image:%IMAGEFACTORY_MNT% /AnalyzeComponentStore

@ECHO Start Component Cleanup
dism /English /Cleanup-Image /Image:%IMAGEFACTORY_MNT% /StartComponentCleanup /ResetBase

@ECHO Scan Health
dism /English /Cleanup-Image /Image:%IMAGEFACTORY_MNT% /ScanHealth

@ECHO Check Health
dism /English /Cleanup-Image /Image:%IMAGEFACTORY_MNT% /CheckHealth

@ECHO Unmount image
dism /English /Unmount-Wim /MountDir:%IMAGEFACTORY_MNT% /Commit

@ECHO Preparing our new ISO ...
"%IMAGEFACTORY_ZIP%" x -o%IMAGEFACTORY_WORK_DIR%\iso "%IMAGEFACTORY_ORIGINAL_ISO%" >nul
del /F %IMAGEFACTORY_WORK_DIR%\iso\sources\install.wim

@ECHO Extracting image to ISO
dism /English /Quiet /Export-Image /SourceImageFile:%IMAGEFACTORY_WORK_DIR%\install.wim /SourceIndex:1 /DestinationImageFile:%IMAGEFACTORY_WORK_DIR%\iso\sources\install.wim /Compress:max

@ECHO Copy Autounattend.xml into image
copy Autounattend.xml %IMAGEFACTORY_WORK_DIR%\iso\

@ECHO Create new ISO
OSCDIMG -m -o -u2 -udfver102 -bootdata:2#p0,e,b%IMAGEFACTORY_WORK_DIR%\iso\boot\etfsboot.com#pEF,e,b%IMAGEFACTORY_WORK_DIR%\iso\efi\microsoft\boot\efisys.bin %IMAGEFACTORY_WORK_DIR%\iso Windows_11_Pro_Custom.iso

@ECHO.
@ECHO Finished
@ECHO ========
@ECHO.

@ECHO You can now install your personal Windows 11 Pro by using
@ECHO.
@ECHO     %~dp0Windows_11_Pro_Custom.iso
@ECHO.
@ECHO If you want to install your system via USB use a tool like rufus
@ECHO.
@ECHO     https://rufus.ie
@ECHO.
@ECHO and prepare your USB stick with the original Windows ISO. Then
@ECHO run
@ECHO.
@ECHO     updateusb.iso
@ECHO.
@ECHO To transfer the windows image and unattended file to the USB stick
@ECHO.
@ECHO You can also remove the work directory now.
@ECHO.
@ECHO     RD /S %IMAGEFACTORY_WORK_DIR%
@ECHO.
GOTO :finish

:err_no_image
@ECHO.
@ECHO Unable to find the Windows 11 ISO (Win11*.iso) in your current directory.
@ECHO Ensure you download "Windows 11 Disk Image (ISO) for x64 devices" from
@ECHO https://www.microsoft.com/en-us/software-download/windows11 and copy
@ECHO the ISO file into the same directory as the build.bat file
goto :finish

:err_no_patch
@ECHO.
@ECHO Unable to find the installation file for KB5037771 in this directory.
@ECHO You should be able to find the last cumulative patch here
@ECHO.
@ECHO     https://catalog.update.microsoft.com/Search.aspx?q=Cumulative%%20Update%%20for%%20Windows%%2011%%20Version%%2023H2%%20for%%20x64-based%%20Systems
@ECHO.
@ECHO Please download KB5037771 and store the MSU file in the same directory as
@ECHO build.bat
@ECHO.
@ECHO If you do not want to build the patch into the image, or you downloaded a
@ECHO more recent one than KB5037771 you will have to remove the check and commands
@ECHO inside build.bat. In order to do that search for
@ECHO.
@ECHO     IMAGEFACTORY_ORIGINAL_MSU
@ECHO.
@ECHO inside build.bat
goto :finish

:err_no_oscdimg
@ECHO.
@ECHO Unable to find the OSCDIMG binary. Are you sure you run this from an ADK
@ECHO environment? Ensure to download ADK from
@ECHO.
@ECHO     https://go.microsoft.com/fwlink/?linkid=2243390
@ECHO.
@ECHO check "Deploymenttools" on installation. After a successfull installation you
@ECHO should find a new start menu entry "Windows Kits" that allows to run a
@ECHO command line with relevant environment settings set. Start this with
@ECHO administrative permissions. Navigate back to this folder and run batch.bat
@ECHO again.
goto :finish

:err_no_lgpo
@ECHO.
@ECHO Unable to find the tool LGPO. This is necessary to write local group policy
@ECHO settings into an offline image. You can download LGPO from Microsoft from
@ECHO.
@ECHO     https://www.microsoft.com/en-us/download/details.aspx?id=55319
@ECHO.
@ECHO On the above website click download and select "LGPO.exe". Extract the
@ECHO LGPO.exe binary from the downloaded ZIP file and copy it to this directory.
goto :finish

:err_no_edge_policy
@ECHO.
@ECHO Unable to find the Microsoft Edge policy template cabinet
@ECHO.
@ECHO     %IMAGEFACTORY_EDGE_POLICY%
@ECHO.
@ECHO These are necessary since our Group Policy contains settings for a
@ECHO privacy friendly Microsoft Edge Browser. You can download the file from
@ECHO.
@ECHO     https://www.microsoft.com/de-de/edge/business/download
@ECHO.
@ECHO Download the policy (not the browser) and place the file in the current
@ECHO directory
goto :finish

:err_no_chrome_policy
@ECHO.
@ECHO Unable to find the Google Chrome policy templates
@ECHO.
@ECHO     %IMAGEFACTORY_GOOGLE_CHROME_POLICY%
@ECHO.
@ECHO These are necessary since our Group Policy contains settings for a
@ECHO privacy friendly Google Chrome browser. You can download the file from
@ECHO.
@ECHO     https://chromeenterprise.google/intl/de_de/browser/download/#manage-policies-tab
@ECHO.
@ECHO Place the policy_templates.zip in the current directory. You do not have to
@ECHO extract the ZIP file.
goto :finish

:err_no_chrome_setup
@ECHO.
@ECHO Unable to find the Google Chrome setup file
@ECHO.
@ECHO     %IMAGEFACTORY_GOOGLE_CHROME_SETUP%
@ECHO.
@ECHO This is necessary to install Google Chrome on first login.
@ECHO Ensure to download the Google Chrome Setup (as MSI, not bundle) from
@ECHO.
@ECHO     https://chromeenterprise.google/intl/de_de/browser/download/#windows-tab
@ECHO.
@ECHO and place the MSI file in the current directory
goto :finish

:err_no_zip_setup
@ECHO.
@ECHO Unable to find the 7-Zip installation file
@ECHO.
@ECHO     %IMAGEFACTORY_ZIP_SETUP%
@ECHO.
@ECHO This file is copied into the image in order to install it
@ECHO on first login. Ensure to download the file from
@ECHO.
@ECHO     https://7-zip.org/a/7z2403-x64.msi
@ECHO.
@ECHO And place the setup file inside this directory
goto :finish

:err_no_sumatrapdf
@ECHO.
@ECHO Unable to find the SumatraPDF install file
@ECHO.
@ECHO     %IMAGEFACTORY_SUMATRAPDF%
@ECHO.
@ECHO This file is copied into the image in order to install it
@ECHO on first login. Ensure to download the file from
@ECHO.
@ECHO     https://www.sumatrapdfreader.org/dl/rel/3.5.2/SumatraPDF-3.5.2-64-install.exe
@ECHO.
@ECHO And place the setup file inside this directory
goto :finish

:err_no_dism
@ECHO.
@ECHO DISM is either not working or you are not running this script with elevated
@ECHO permissions.
goto :finish

:err_no_zip
@ECHO.
@ECHO Unable to find %IMAGEFACTORY_ZIP%. This script uses 7zip to extract the
@ECHO original ISO file. You can download 7zip from
@ECHO.
@ECHO     https://7-zip.org
@ECHO.
@ECHO Ensure to install it to the default location
goto :finish

:err_work_already_exists
@ECHO.
@ECHO The directory "work" does already exist. This is most likely from a previous
@ECHO run of build.bat. Ensure you remove the directory before you run the script
@ECHO again. You can do this from the command line by running the following
@ECHO command:
@ECHO.
@ECHO     RD /S %IMAGEFACTORY_WORK_DIR%
@ECHO.
goto :finish

:err_driver_not_found
@ECHO.
@ECHO The driver %IMAGEFACTORY_MISSING_DRIVER% was not found in the exported
@ECHO directory. You should adapt the build.bat and ensure you are installing the
@ECHO correct drivers. If you want to install all 3rd party drivers from your
@ECHO current machine (this makes sense when the installation media should be used
@ECHO to install Windows 11 on your current machine) execute
@ECHO.
@ECHO     findDriver.bat
@ECHO.
@ECHO and follow the instructions in the generated
@ECHO.
@ECHO     driver-snippet.txt
@ECHO.
@ECHO file
goto :finish

:err_product_key_not_changed
@ECHO.
@ECHO It looks like you forgot to adapt your Product Key in Autounattend.xml. The
@ECHO product key that is mentioned in the file "ABCD1-EF2G3-4HI5J-KL6MN-OP7QR" is
@ECHO only for demonstration purpose. Please modify
@ECHO.
@ECHO     %~dp0Autounattend.xml
@ECHO.
@ECHO Search for the string "ABCD1-EF2G3-4HI5J-KL6MN-OP7QR" in the file and replace
@ECHO it with your actual product key
goto :finish

:err_user_not_changed
@ECHO.
@ECHO It looks like you forgot to adapt the local username in Autounattend.xml that
@ECHO will be created on your new system. Your probably do not want to call the
@ECHO user User001. Open the file
@ECHO.
@ECHO     %~dp0Autounattend.xml
@ECHO.
@ECHO and replace all occurances of User001 with your desired username. This will
@ECHO set the initial password to the same name as your username but you are forced
@ECHO to change it on next login.
goto :finish

:err_ads
@ECHO.
@ECHO The following file
@ECHO.
@ECHO     !IMAGEFACTORY_ADS!
@ECHO.
@ECHO is currently marked as downloaded from the internet.
@ECHO This flag will prevent the execution of the file without
@ECHO user intervention. Ensure to remove the flag. To do that
@ECHO right-click the file and see the properties. Then check
@ECHO security box to unblock the file. Alternatively run
@ECHO.
@ECHO     Unblock-File -Path %~dp0!IMAGEFACTORY_ADS!
@ECHO.
@ECHO In an elevated powershell terminal
goto :finish

:finish
ENDLOCAL
