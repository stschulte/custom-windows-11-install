# Custom Windows 11 Image

This repository assists you in creating your custom Windows 11 Installation media.
Some of the goals:

- Installation media installs Windows 11 Pro without any user interaction
- Local account instead of a Microsoft Account
- Disable OneDrive, Chat, and other features I don't want to use
- Larger EFI partition since I want to dual-boot into Linux and want to store different
  linux kernel on the EFI partition
- Bake necessary drivers and windows updates into the image
- Privacy settings and disabled telemetry before the user logs in
- Possible have the latest backup archive directly present on the new system to
  restore data with one click
- build the image in a reproducable way

This repository includes the final `build.bat` to automate the build process
of your custom `iso` file and an `Autounattend.xml` file that automates the
installation.

You can either modify these, or start completly from scratch.

## Prerequisite

In order to build a custom windows image, we need to install a few tools
and download necessary components:

- Clone the repository into a directory. The directory includes our `build.bat`
- Download [Windows 11 Disk Image (ISO)][Win11] and store the ISO in the same directory as the `build.bat` file
- Download the December 2023 Update for Windows 11 [KB5033375][KB5033375] and store it in the same directory as the `build.bat` file.
  You can also use a more recent file, as long as you adapt the `build.bat`
- Download [Windows ADK][ADK] and install "Deploymenttools" (in German: "Bereitstellungstools")
- Download [7-zip][ZIP] and install it to the default path.
- Download [LGPO.exe][LGPO] and store the binary in the same directory as the `build.bat`

After installing the [ADK][ADK], you should have a new start menu entry for a specialized command line
environment. Make sure to start this as administrator and navigate to the git checkout.
Otherwise `build.bat` will complain to not find `OSCDIMG` which is part of the ADK

## TLDR

After fullfilling the prerequisites, modify the `Autounattend.xml` to set your username and inital password
and set the `ProductKey`. Run ` findDriver.bat` and follow the instructions of the created `driver-snippet.txt`.
Then run `build.bat`.

## Building your custom image step by step

In case you are interested how the image creation works, I recommend to do it step by step once. This
allows you to understand the whole process and hopefully gives you more confidence in changing `build.bat`
to your needs.

Make sure you run through the "Prerequisite" section before you continue with the next section.

### Overview

In order to understand how we can influence the installation, we first need to understand
what happens when the user boots from an installation media:

1. Collect data through user input (e.g. desired username, what disk should be used)
2. Prepare the disk, e.g. partition the disk and format the system partition
3. Copy a generic base image (called `install.wim`) to the selected disk partition
4. Reboot into the new system and specialize the image (e.g. generating unique IDs, creating a user)
5. On first login run some additional commands (e.g. install software)

If you want to influence what is installed on your fresh Windows 11 (let's say you don't care to
have `BingWeather` installed), you'll have two options:

- Patch the base image that is present on the installation media before you even attempt the installation.
  If the base image does not include `BingWeather`, your final Windows 11 also won't.
- Run a script on first boot to remove the software

The first option is peferred and manipulates an offine image (that means we manipulate an image
that is not currently started), the second version would be an online change (change the currently
running system).

As a result we first concentrate to change the offline image that is present on the installation
ISO.

### Change the offline image

When you install Windows, the setup applies a generic image to your disk. We can extract the image from
the ISO file and manipulate it. I assume you are in the checkout of the repository and the downloaded
Windows ISO is in the same directory. Let's create a temporary `work` directory and extract the file
`sources\install.wim` from the installation media to `work\sources`.

```text
MD work
MD work\sources
"%ProgramFiles%\7-Zip\7z.exe" e -owork\sources Win11_23H2_*_x64.iso sources\install.wim
```

We should now have a file `work\sources\install.wim`. Let's inspect the available versions in the image:

```text
dism /Get-WimInfo /WimFile:work\sources\install.wim
```

We are interested in Windows 11 Pro, which is index `5` in our case:

```text
Index : 5
Name : Windows 11 Pro
Description : Windows 11 Pro
Size : 18.788.136.037 bytes
```

So let's extract this image into a new one first:

```text
dism /Export-Image /SourceImageFile:work\sources\install.wim /SourceIndex:5 /DestinationImageFile:work\install.wim /Compress:max
```

We should now have a file `work\install.wim` which should be smaller than `work\sources\install.wim`. This image only has one index `1`.
We can now mount this image and see the actual content:

```text
MD work\mnt
dism /Mount-Wim /WimFile:work\install.wim /Index:1 /MountDir:work\mnt
```

The directory `work\mnt` should now contain a complete system, e.g. you should be able to see a `work\mnt\Windows`.

#### Remove Apps

In the previous step we have mounted an offline image to `work\mnt`. We can now use this to remove unnecessary applications. Run the following
to list the currently configured apps:

```text
dism /Image:work\mnt /Get-ProvisionedAppxPackages
```

We can now remove packages we do not want:

```text
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Clipchamp.Clipchamp_2.2.8.0_neutral_~_yxz26nhyzhsrt
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.549981C3F5F10_3.2204.14815.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.BingNews_4.2.27001.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.BingWeather_4.53.33420.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.GamingApp_2021.427.138.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.GetHelp_10.2201.421.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Getstarted_2021.2204.1.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.MicrosoftOfficeHub_18.2204.1141.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.MicrosoftStickyNotes_4.2.2.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.People_2020.901.1724.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.PowerAutomateDesktop_10.0.3735.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Todos_2.54.42772.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsAlarms_2022.2202.24.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsCamera_2022.2201.4.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:microsoft.windowscommunicationsapps_16005.14326.20544.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsFeedbackHub_2022.106.2230.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsMaps_2022.2202.6.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.WindowsSoundRecorder_2021.2103.28.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.Xbox.TCUI_1.23.28004.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxGameOverlay_1.47.2385.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxGamingOverlay_2.622.3232.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxIdentityProvider_12.50.6001.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.XboxSpeechToTextOverlay_1.17.29001.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.YourPhone_1.22022.147.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.ZuneMusic_11.2202.46.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:Microsoft.ZuneVideo_2019.22020.10021.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:MicrosoftCorporationII.QuickAssist_2022.414.1758.0_neutral_~_8wekyb3d8bbwe
dism /Image:work\mnt /Remove-ProvisionedAppxPackage /PackageName:MicrosoftWindows.Client.WebExperience_421.20070.195.0_neutral_~_cw5n1h2txyewy
```

#### Remove Capabilities

Now let's loook into "capabilities":

```text
dism /Image:work\mnt /Get-Capabilities
```

We can also learn more about a specific capability, e.g. `Hello.Face.20134~~~~0.0.1.0`:

```text
dism /Image:work\mnt /Get-CapabilityInfo /CapabilityName:Hello.Face.20134~~~~0.0.1.0
```

I am not interested in Windows Hello and I don't have WiFi, so I remove capabilities associated with that.
My Desktop PC is also not capable to track my steps, so let's remove the `StepsRecorder` as well.
You can specify more than one capability, the following is one single command and should only be one line:

```text
dism /Image:work\mnt /Remove-Capability /CapabilityName:Hello.Face.20134~~~~0.0.1.0 /CapabilityName:App.StepsRecorder~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Broadcom.Bcmpciedhd63~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63al~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63a~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwbw02~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwew00~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwew01~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwlv64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwns64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwsw00~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw02~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw04~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw06~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw08~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Intel.Netwtw10~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Marvel.Mrvlpcie8897~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Qualcomm.Athw8x~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Qualcomm.Athwnx~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Qualcomm.Qcamain10x64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Ralink.Netr28x~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl8187se~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl8192se~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl819xp~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtl85n64~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtwlane01~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtwlane13~~~~0.0.1.0 /CapabilityName:Microsoft.Windows.Wifi.Client.Realtek.Rtwlane~~~~0.0.1.0
```

#### Remove Features

Now let's look into activated features:

```text
dism /Image:work\mnt /Get-Features
```

We can remove features we are not interested in. I will remove MSRDC-Infrastructure, SearchEngine-Client-Package and WorkFolders-Client.
You can specify more than one feature at a time, so make sure everything is on one line:

```text
dism /Image:work\mnt /Disable-Feature /FeatureName:MSRDC-Infrastructure /FeatureName:SearchEngine-Client-Package /FeatureName:WorkFolders-Client
```

#### Adding drivers

We can also install drivers into the offline image. This will make sure that your hardware is ready to use after you installed Windows 11.
In my usecase I want to install Windows 11 on the same machine as my current Windows 10 and the same machine I use to build the image.
So the approach I want to take is:

1. Ensure all drivers are up-to-date on my build system.
2. I may have drivers installed that belong to hardware that is no longer present. So I have to map all 3rd
   party drivers to actually present devices
3. Include the active driver into the image

We first export all 3rd party drivers of the current system (this is why we specify `/Online` instead of an image) to a directory

```text
MD work\driver
dism /Online /Export-Driver /Destination:work\driver
```

You should get a result like this:

```text
Exporting 1 of 23 - oem0.inf: The driver package successfully exported.
[...]
Exporting 23 of 23 - oem9.inf: The driver package successfully exported.
The operation completed successfully.
```

We can use `dism` and `/Add-Driver` to specify a single `*.inf` file from `work\driver`.
to install a driver to our offline image. Unfortunately it is not so easy to identify
which `.inf` file is relevant. One approach would be to open the device manager, inspect
all present devices what inf file they use. This should give you something like `oem9.inf`.
You then need to know the original filename that is present in `work\driver`. We
can run `dism /Online /Get-Drivers` in order to map between the `oem` filename and the
original filename. However this is really tedious work.

I automated all this, so we simply run

```text
findDriver.bat
type driver-snippet.txt
```

The file `driver-snippet.txt` gives some help on how to patch the `build.bat` but it also
gives us a stand-alone `dism` command. In my case this would be

```text
dism /Image:work\mnt /Add-Driver /Driver:work\driver\amdafd.inf_amd64_98939332ba1b458a\amdafd.inf /Driver:work\driver\amdfendr.inf_amd64_790c3b89d61d232e\amdfendr.inf /Driver:work\driver\cyucmclient.inf_amd64_3d5e258995978aa0\cyucmclient.inf /Driver:work\driver\lgsusb.inf_amd64_c6a29e4cd588cf6a\lgsusb.inf /Driver:work\driver\smbusamd.inf_amd64_246caabd058be11f\smbusamd.inf /Driver:work\driver\tbthostcontroller.inf_amd64_90f6a13df0927823\tbthostcontroller.inf /Driver:work\driver\tbthostcontrollerhsacomponent.inf_amd64_d31d2cc1c9ebc4c5\tbthostcontrollerhsacomponent.inf /Driver:work\driver\u0396906.inf_amd64_85a7dd2e12f92c85\u0396906.inf /Driver:work\driver\e2f.inf_amd64_2d5cb0c750512550\e2f.inf /Driver:work\driver\amdgpio2.inf_amd64_26fd146b41c45ce2\amdgpio2.inf /Driver:work\driver\asusswc.inf_amd64_a4fdd01ce4b4de03\asusswc.inf /Driver:work\driver\ctxhda.inf_amd64_1239ba03e9051498\ctxhda.inf /Driver:work\driver\amdgpio3.inf_amd64_f03ace476a8fec30\amdgpio3.inf /Driver:work\driver\amdocl.inf_amd64_3f5ad05be848c8d0\amdocl.inf /Driver:work\driver\amdpcidev.inf_amd64_2dbed7efd5f2b448\amdpcidev.inf /Driver:work\driver\amdpsp.inf_amd64_3d8eba6178a9a15e\amdpsp.inf /Driver:work\driver\asussci2.inf_amd64_4fc38a913e0f2ea5\asussci2.inf /Driver:work\driver\atihdwt6.inf_amd64_e054ad64864d19d3\atihdwt6.inf
```

#### Disable services

Windows 11 comes with a lot of services, we may not need (e.g. diagnotics, Xbox services). It would be
great if these would be configured as `disabled` in our offline image, so they never even start.

The startup type of services is stored in the registry which we can load from the offline image:

```text
reg load HKLM\OFFLINE work\mnt\Windows\System32\config\SYSTEM
```

You can open the Registry Editor and make changes under the imported structure `HKEY_LOCAL_MACHINE\OFFLINE`.
I will use the command line to disable services by changing the start type to `4` (disabled).

```text
reg add HKLM\OFFLINE\ControlSet001\Services\AJRouter /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\autotimesvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\cloudidsvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\diagnosticshub.standardcollector.service /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\DiagTrack /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\dmwappushservice /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\dot3svc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\HvHost /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\icssvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\lmhosts /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\MSiSCSI /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\PcaSvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\PhoneSvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\PushToInstall /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\RetailDemo /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\SCPolicySvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\SEMgrSvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\ShellHWDetection /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\spectrum /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\TapiSrv /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmicguestinterface /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmicheartbeat /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmickvpexchange /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmicrdv /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmicshutdown /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmictimesync /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmicvmsession /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\vmicvss /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\WalletService /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\WbioSrvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\wisvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\WlanSvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\wlidsvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\WpcMonSvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\WSearch /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\XblAuthManager /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\XblGameSave /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\XboxGipSvc /v START /t REG_DWORD /d 4 /f
reg add HKLM\OFFLINE\ControlSet001\Services\XboxNetApiSvc /v START /t REG_DWORD /d 4 /f
```

#### Use UTC as system clock

I will also tell Windows that the System Clock (the clock you specify in BIOS) runs
in UTC instead of your local timezone. You will still see the time in your local timezone
in Windows but there is no confusion when to adapt for Daylight Saving Time.

This is particularily helpfule when booting more than one operating system: If the system
clock runs in the local time format, the different operating systems have to coordinate who
is responsible to adapt the clock after a DST switch. This does not happen when the system
clock runs in universal time.

```text
reg add HKLM\OFFLINE\ControlSet001\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_QWORD /d 1
```

You can make further changes if you want to. Once you are done, you have to unload the registry again.

```text
reg unload HKLM\OFFLINE
```

#### Disable content delivery manager

We now also want to disable the content delivery manager. These registry settings are part of the
user specific registry. Since we do not have a user right now we can modify the registry of the
default user, so our settings will be applied to all new users:

```text
reg load HKLM\OFFLINE work\mnt\Users\Default\NTUSER.DAT
```

Now disable content delivery manager

```text
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v FeatureManagementEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SlideshowEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f
reg add "HKLM\OFFLINE\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f
```

I am also not interested in OneDrive so I disable the setup on first launch:

```text
reg delete "HKLM\OFFLINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f
```

We can unload the registry again.

```text
reg unload HKLM\OFFLINE
```

#### Disable OneDrive

While removing the registry setting _should_ disable OneDriver it was still installed in my runs. What
finally works is removing the setup file. A simple `move` will fail however:

```text
move work\mnt\Windows\System32\OneDriveSetup.exe work\mnt\Windows\System32\OneDriveSetup.backup
```

You will see a permission denied. This is because we (as administrators) are not the owner of the
file. The file is owned by `NT SERVICE\Trusted Installer`

```text
dir /Q work\mnt\Windows\System32\OneDriveSetup.exe

07.05.2022  11:39        50.312.608 NT SERVICE\TrustedInstaOneDriveSetup.exe
```

and while we (as adminsitrators) have read and execute permissions (RX), we do not have full permissions (F):

```text
icacls work\mnt\Windows\System32\OneDriveSetup.exe

work\mnt\Windows\System32\OneDriveSetup.exe NT SERVICE\TrustedInstaller:(F)
                                            VORDEFINIERT\Administratoren:(RX)
                                            NT-AUTORITÄT\SYSTEM:(RX)
                                            VORDEFINIERT\Benutzer:(RX)
                                            ZERTIFIZIERUNGSSTELLE FÜR ANWENDUNGSPAKETE\ALLE ANWENDUNGSPAKETE:(RX)
                                            ZERTIFIZIERUNGSSTELLE FÜR ANWENDUNGSPAKETE\ALLE EINGESCHRÄNKTEN ANWENDUNGSPAKETE:(RX)
```

Please note that my system runs in German and groups and users are localized. So `VORDEFINIERT\Administratoren` is probably called `BUILTIN\Administrators` on your system.
This is why we will later use the SID `S-1-5-32-544` instead of the name. The SID is always the same.
To rename the file, we first change the owner to the administrator group. We then give the administrator group
full permissions in order to rename it. We then restore the old permissions on he renamed file.

```text
takeown /F work\mnt\Windows\System32\OneDriveSetup.exe /A
icacls work\mnt\Windows\System32\OneDriveSetup.exe /grant *S-1-5-32-544:F

move work\mnt\Windows\System32\OneDriveSetup.exe work\mnt\Windows\System32\OneDriveSetup.backup

icacls work\mnt\Windows\System32\OneDriveSetup.backup /setowner "NT SERVICE\TrustedInstaller"
icacls work\mnt\Windows\System32\OneDriveSetup.backup /grant:r *S-1-5-32-544:RX
```

#### Group Policies

Unfortunately _a lot_ of changes - including privacy related ones - cannot be changed easily. But some are
exported through Group Policy settings. My opinionated group policies are exported as text file as `lgpo.m.txt`
for machine based policy settings and `lgpo.u.txt` for user based policy settings.

To apply the text based group policies to our offline image we can run

```text
MD work\mnt\Windows\System32\GroupPolicy\Machine
MD work\mnt\Windows\System32\GroupPolicy\User
LGPO.exe /r lgpo.m.txt /w work\mnt\Windows\System32\GroupPolicy\Machine\Registry.pol
LGPO.exe /r lgpo.u.txt /w work\mnt\Windows\System32\GroupPolicy\User\Registry.pol
```

We also have to specify some GPO Extension otherwise some group policy settings (e.g. for Windows Defender) will
not be applied. The following code generates a `gpt.ini` file.

```text
echo [General] > work\mnt\Windows\System32\GroupPolicy\gpt.ini
echo Version=65537 >> work\mnt\Windows\System32\GroupPolicy\gpt.ini
echo gPCMachineExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{D02B1F72-3407-48AE-BA88-E8213C6761F1}][{F312195E-3D9D-447A-A3F5-08DFFA24735E}{D02B1F72-3407-48AE-BA88-E8213C6761F1}]  >> work\mnt\Windows\System32\GroupPolicy\gpt.ini
echo gPCUserExtensionNames=[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{D02B1F73-3407-48AE-BA88-E8213C6761F1}] >> work\mnt\Windows\System32\GroupPolicy\gpt.ini
```

If you have a reference system for group policies, you can create your own `lgpo.u.txt` file
on your reference machine:

```text
LGPO.exe /parse /u "C:\Windows\System32\GroupPolicy\User\Registry.pol" > lgpo.u.txt
LGPO.exe /parse /m "C:\Windows\System32\GroupPolicy\Machine\Registry.pol" > lgpo.m.txt
```

You should also inspect the `gpt.ini` file of your reference system for potentially needed
`gPCMachineExtensionNames` and `gPCUserExtensionNames` settings.

#### Windows updates

It makes sense to install the latest incremental update into the offline image so we do not have to run through
a lengthy update procedure after the installation. At the time of writing this was [KB5033375][KB5033375].
Download the update and install it into the image. Please be aware that this can take quite some time.

```text
dism /Image:work\mnt /Add-Package /PackagePath:windows11.0-kb5033375-x64_516f4fb2bb560cddf08e9d744de8029f802dec21.msu
```

#### Include additional files

I also add additional files into the image to ease migration. You can skip this step.

I assume you have created a directory `TransportTruck` that includes your latest backup as a zip file,
some installation files, or anything that you need to be available on your new system to get going.

To copy the `TransportTruck` into the image we can run the following:

```text
xcopy /S /E /H /I TransportTruck work\mnt\TransportTruck
```

(`/S /E` also copies subdirectories, `/H` copies hidden files and `/I` ensures the target is treated as a directory)

After the installation, this will be available as `C:\TransportTruck` on the new system.

#### Umount the offline image

If you are happy with your offline image, we can try to get back some space (especially after the windows update)
by doing a `StartComponentCleanup`. We then check the image and commit our changes.

```text
dism /Cleanup-Image /Image:work\mnt /AnalyzeComponentStore
dism /Cleanup-Image /Image:work\mnt /StartComponentCleanup /ResetBase
dism /Cleanup-Image /Image:work\mnt /ScanHealth
dism /Cleanup-Image /Image:work\mnt /CheckHealth
dism /Unmount-Wim /MountDir:work\mnt /Commit
```

### Create an Autounattend.xml

Now that our offline image is ready, we need a file to automate the installation process. You can use the
`Autounattend.xml` in this repository. Here are some relevant sections:

Under the `Microsoft-Windows-Setup` component we can configure our Product Key:

```xml
<UserData>
  <AcceptEula>true</AcceptEula>
  <ProductKey>
    <Key>ABCD1-EF2G3-4HI5J-KL6MN-OP7QR</Key>
  </ProductKey>
</UserData>
```

We can also specify a `DiskConfiguration`. This can be used to format disks and specify where to install
the image. Please be aware that this will format your disk without asking for confirmation. If you have
multiple disks in your system you want to double check that `DiskID` `0` actually specifies the correct
disk. If you remove the `DiskConfiguration` section, the setup will ask you where to install Windows.

You should also change the language settings in the components `Microsoft-Windows-International-Core-WinPE` and
`Microsoft-Windows-International-Core`.

In order to run the installation completly unattended, the `Autounattended.xml` file does three things to avoid
user interaction:

1. We create a local user with a simple password (user: `User001`, password: `User001`). This user will be the main
   account on the new machine. Do not worry about the password, the user will be forced to change it later.
   You should change the username to your desired username.
2. We configure autologin with the username and password. When Windows boots for the first time, windows can
   directly log into our user to complete the installation.
3. On first login (which now happens automatically), we disable autologin again and force the user
   to change the password on next login.

You most certainly want to change the username under `LocalAccounts`, `AutoLogon` and `FirstLogonCommands`.
Here is the relevant snippet from `Autounattend.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" language="neutral" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" publicKeyToken="31bf3856ad364e35" versionScope="nonSxS">
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>User001</Name>
            <DisplayName>User001</DisplayName>
            <Group>Administrators</Group>
            <Password>
              <Value>User001</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Password>
          <Value>User001</Value>
          <PlainText>true</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <Username>User001</Username>
        <LogonCount>1</LogonCount>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
            <Order>1</Order>
            <CommandLine>net user &quot;User001&quot; /logonpasswordchg:yes</CommandLine>
            <Description>Ensure to change the password</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
            <Order>2</Order>
            <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonCount /t REG_DWORD /d 0 /f</CommandLine>
            <Description>Disable autologon after installation</Description>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
```

### Build an image

At this point, you should have two things:

- a custom windows image `work\install.wim`
- installation instructions in `Autounattend.xml`

We can now build a new installation media. First we extract the original ISO file
into `work\iso`

```text
"%ProgramFiles%\7-Zip\7z.exe" x -owork\iso Win11_23H2_*_x64.iso
```

Now we can replace the original `sources\install.vim` with our custom version

```text
del /F work\iso\sources\install.wim
dism /Export-Image /SourceImageFile:work\install.wim /SourceIndex:1 /DestinationImageFile:work\iso\sources\install.wim /Compress:max
```

NOTE: We export the image here again as this will drastically reduce the size of the `install.wim` in our new ISO.

We also copy our `Autounattend.xml` to the new image:

```text
copy Autounattend.xml work\iso\
```

We can finally build our own ISO file out of the `work\iso` directory. We make sure this ISO is bootable both in MBR and UEFI mode:

```text
OSCDIMG -m -o -u2 -udfver102 -bootdata:2#p0,e,bwork\iso\boot\etfsboot.com#pEF,e,bwork\iso\efi\microsoft\boot\efisys.bin work\iso Windows_11_Pro_Custom.iso
```

You now have your own `Windows_11_Pro_Custom.iso` file. You can either burn this to a DVD, use it in Virtual Box to provision a VM or
use a tool like [rufus][RUFUS] to create a USB stick for the installation.

When using rufus or VirtualBox ensure to disable unattended installation inside the tools as this will interfer with the `Autounattended.xml`
that is already inside your ISO.

You can now remove the `work` directory again.

```text
RD /S work
```

## Build image via script

Before we can execute `build.bat` we first have to modify it.

### Section Validating Environment

We can include drivers in our custom image. This ensures that all hardware components can be used
directly after the installation happened. In the beginning of the `build.bat` script you will find
a line.

```text
IMAGEFACTORY_DRIVERS=
```

In my case the machine where I build the image is the same machine where I want to install windows 11.
So I want to specify all 3rd party drivers that belong to hardware that is currently installed on my
machine. In this case we can execute the small helper script `findDriver.bat`. It has to run with
admin priviledges in order to get a list of current drivers and their original installation names.
It will then compare this with currently installed hardware and generate a list of driver names.
Make sure all hardware is connected to your machine at this point, otherwise the driver will not
be included. The result of the file `driver-snippet.txt` may look similar to this:

```text
Add the following to the build.bat, replacing the current SET IMAGEFACTORY_DRIVERS line:
8>-----8>-----8>-----8>-----8>-----8>-----
SET IMAGEFACTORY_DRIVERS=work\driver\amdafd.inf_amd64_98939332ba1b458a\amdafd.inf work\driver\amdfendr.inf_amd64_790c3b89d61d232e\amdfendr.inf work\driver\cyucmclient.inf_amd64_3d5e258995978aa0\cyucmclient.inf work\driver\lgsusb.inf_amd64_c6a29e4cd588cf6a\lgsusb.inf work\driver\smbusamd.inf_amd64_246caabd058be11f\smbusamd.inf work\driver\tbthostcontroller.inf_amd64_90f6a13df0927823\tbthostcontroller.inf work\driver\tbthostcontrollerhsacomponent.inf_amd64_d31d2cc1c9ebc4c5\tbthostcontrollerhsacomponent.inf work\driver\u0396906.inf_amd64_85a7dd2e12f92c85\u0396906.inf work\driver\e2f.inf_amd64_2d5cb0c750512550\e2f.inf work\driver\amdgpio2.inf_amd64_26fd146b41c45ce2\amdgpio2.inf work\driver\asusswc.inf_amd64_a4fdd01ce4b4de03\asusswc.inf work\driver\ctxhda.inf_amd64_1239ba03e9051498\ctxhda.inf work\driver\amdgpio3.inf_amd64_f03ace476a8fec30\amdgpio3.inf work\driver\amdocl.inf_amd64_3f5ad05be848c8d0\amdocl.inf work\driver\amdpcidev.inf_amd64_2dbed7efd5f2b448\amdpcidev.inf work\driver\amdpsp.inf_amd64_3d8eba6178a9a15e\amdpsp.inf work\driver\asussci2.inf_amd64_4fc38a913e0f2ea5\asussci2.inf work\driver\atihdwt6.inf_amd64_e054ad64864d19d3\atihdwt6.inf work\driver\dpumdf.inf_amd64_8e23525834f62e28\dpumdf.inf
<8-----<8-----<8-----<8-----<8-----<8-----
[...]
```

We can now replace the line `SET IMAGEFACTORY_DRIVERS` in the build.bat script and replace it with the
complete line from the output file.

If you do not want to install any drivers, simply remove the line completly.

You will also find the following three lines:

```text
FOR %%x in (windows11.0-kb5033375*.msu) DO SET IMAGEFACTORY_ORIGINAL_MSU=%%x
IF %IMAGEFACTORY_ORIGINAL_MSU% == NOTFOUND GOTO :err_no_patch
@ECHO * KB5033375 found: %IMAGEFACTORY_ORIGINAL_MSU%
```

Ensure `windows11.0-kb5033375*.msu` matches the MSU you downloaded from the [Catalog][CAT]. At the time of writing
the last recent release was [KB5033375][KB5033375], but you may want to adapt this with a
later version you downloaded. If you do not want to install updates into the image at all
you can also remove the lines completly.

### Section Mount the Windows Image

The downloaded windows installation media does include a "Windows Image" file that basically
describes the content of a new system. We can extract and modify this image to add new drivers,
change files, preinstall group policies, modify the registry, etc. A single `wim` file can contain
multiple versions (e.g. Windows 11 Pro and Windows 11 Home), so the first thing we do is create
a `wim` file that only contains the version we are interested in (Windows 11 Pro). You will see this
happens in the `build.bat` file:

```text
dism /Export-Image /SourceImageFile:work\sources\install.wim /SourceIndex:5 /DestinationImageFile:work\install.wim /Compress:max
```

You may have to adapt the index here from `5` to a different number. Run the following commands
to temporarily extract the `install.wim` and inspect it.

```text
"%ProgramFiles%\7-Zip\7z.exe" e -o.\  Win11*.iso sources\install.wim
```

We should now have a `install.wim` in our directory. Now inspect the image:

```
dism /English /Get-WimInfo /WimFile:install.wim
```

In our case the desired index is `5` as can be seen from the output:

```text
Index : 5
Name : Windows 11 Pro
Description : Windows 11 Pro
Size : 18.788.136.037 bytes
```

Adapt your `build.bat` to reference the correct index and remove your manually created `install.wim` again before running `build.bat`

```
DEL install.wim
```

### Modify Autounattend.xml

The `build.bat` will copy the file `Autounattended.xml` into the ISO. You have to modify it first:

Under the `Microsoft-Windows-Setup` component configure your Product Key:

```xml
<UserData>
  <AcceptEula>true</AcceptEula>
  <ProductKey>
    <Key>ABCD1-EF2G3-4HI5J-KL6MN-OP7QR</Key>
  </ProductKey>
</UserData>
```

We can also specify a `DiskConfiguration`. This can be used to format disks and specify where to install
the image. Please be aware that this will format your disk without asking for confirmation. If you have
multiple disks in your system you want to double check that `DiskID` `0` actually specifies the correct
disk. If you remove the `DiskConfiguration` section, the setup will ask you where to install Windows.

You should also change the language settings in the components `Microsoft-Windows-International-Core-WinPE` and
`Microsoft-Windows-International-Core`.

In order to run the installation completly unattended, the `Autounattended.xml` file does three things to avoid
user interaction:

1. We create a local user with a simple password (user: `User001`, password: `User001`). This user will be the main
   account on the new machine. Do not worry about the password, the user will be forced to change it later.
   You should change the username to your desired username.
2. We configure autologin with the username and password. When Windows boots for the first time, windows can
   directly log into our user to complete the installation.
3. On first login (which now happens automatically), we disable autologin again and force the user
   to change the password on next login.

You most certainly want to change the username under `LocalAccounts`, `AutoLogon` and `FirstLogonCommands`.
Here is the relevant snippet from `Autounattend.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" language="neutral" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" publicKeyToken="31bf3856ad364e35" versionScope="nonSxS">
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>User001</Name>
            <DisplayName>User001</DisplayName>
            <Group>Administrators</Group>
            <Password>
              <Value>User001</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Password>
          <Value>User001</Value>
          <PlainText>true</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <Username>User001</Username>
        <LogonCount>1</LogonCount>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
            <Order>1</Order>
            <CommandLine>net user &quot;User001&quot; /logonpasswordchg:yes</CommandLine>
            <Description>Ensure to change the password</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add">
            <Order>2</Order>
            <CommandLine>reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonCount /t REG_DWORD /d 0 /f</CommandLine>
            <Description>Disable autologon after installation</Description>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
```

### Run the script

Ensure you are inside the environment that the `ADK` tool provided and you have opened the
command line interface as administrator.

You can now run `build.bat`. Here is a sample output:

```text
D:\ImageFactory\Stefan>build.bat
Validating environment
======================
* OSCDIMG found
* DISM found and working
* LGPO found
* 7zip found: C:\Program Files\7-Zip\7z.exe
* Windows Image found: Win11_23H2_German_x64.iso
* KB5033375 found: windows11.0-kb5033375-x64_516f4fb2bb560cddf08e9d744de8029f802dec21.msu
* temporary directory "work" does not exist yet

Prepare Directories and drivers
===============================

Export driver from current system

Mount the Windows Image
=======================

Extract install.wim from original ISO
Export Windows 11 Pro Image

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Exporting image
[==========================100.0%==========================]
The operation completed successfully.
Mount Windows 11 Pro Image

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Mounting image
[==========================100.0%==========================]
The operation completed successfully.

In case you abort this script or it fails before the end, you have to unmount the image again. You can do this by running

    dism /Unmount-Wim /MountDir:work\mnt /Discard


Adding Updates
==============

Installing KB5033375 (this can take ~30 minutes)

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Image Version: 10.0.22631.2428

Processing 1 of 1 -
[===========================80.0%==============            ]
[==========================100.0%==========================] The operation completed successfully.

Cleanup: Remove packages
========================

Removing package Clipchamp.Clipchamp
Removing package Microsoft.549981C3F5F10
Removing package Microsoft.BingNews
Removing package Microsoft.BingWeather
Removing package Microsoft.GamingApp
Removing package Microsoft.GetHelp
Removing package Microsoft.Getstarted
Removing package Microsoft.MicrosoftOfficeHub
Removing package Microsoft.MicrosoftStickyNotes
Removing package Microsoft.People
Removing package Microsoft.PowerAutomateDesktop
Removing package Microsoft.Todos
Removing package Microsoft.WindowsAlarms
Removing package Microsoft.WindowsCamera
Removing package microsoft.windowscommunicationsapps
Removing package Microsoft.WindowsFeedbackHub
Removing package Microsoft.WindowsMaps
Removing package Microsoft.WindowsSoundRecorder
Removing package Microsoft.Xbox.TCUI
Removing package Microsoft.XboxGameOverlay
Removing package Microsoft.XboxGamingOverlay
Removing package Microsoft.XboxIdentityProvider
Removing package Microsoft.XboxSpeechToTextOverlay
Removing package Microsoft.YourPhone
Removing package Microsoft.ZuneMusic
Removing package Microsoft.ZuneVideo
Removing package MicrosoftCorporationII.QuickAssist
Removing package MicrosoftWindows.Client.WebExperience

Cleanup: Removing capabilities
==============================

Remove capability Hello.Face.20134~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Broadcom.Bcmpciedhd63~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63al~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Broadcom.Bcmwl63a~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwbw02~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwew00~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwew01~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwlv64~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwns64~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwsw00~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw02~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw04~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw06~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw08~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Intel.Netwtw10~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Marvel.Mrvlpcie8897~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Qualcomm.Athw8x~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Qualcomm.Athwnx~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Qualcomm.Qcamain10x64~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Ralink.Netr28x~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl8187se~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl8192se~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl819xp~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtl85n64~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtwlane01~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtwlane13~~~~0.0.1.0
Remove capability Microsoft.Windows.Wifi.Client.Realtek.Rtwlane~~~~0.0.1.0
Remove capability App.StepsRecorder~~~~0.0.1.0

Cleanup: Disable Features
==============================

Remove feature MSRDC-Infrastructure
Remove feature SearchEngine-Client-Package
Remove feature WorkFolders-Client

Customize: Add drivers
======================

Add drivers for High Definition Audio Bus
Add drivers for AMD Crash Defender
Add drivers for Cypress UCM-Client-Peripherie-Treiber
Add drivers for Logitech Download Assistant
Add drivers for AMD SMBus
Add drivers for Thunderbolt(TM) Controller - 1137
Add drivers for Thunderbolt(TM) HSA Component
Add drivers for AMD Radeon RX 5700 XT
Add drivers for Intel(R) Ethernet Controller (3) I225-V
Add drivers for AMD GPIO Controller
Add drivers for ASUS App Component
Add drivers for Sound BlasterX AE-5 Plus
Add drivers for AMD GPIO Controller
Add drivers for AMD-OpenCL User Mode Driver
Add drivers for AMD PCI
Add drivers for AMD PSP 11.0 Device
Add drivers for ASUS System Control Interface v3
Add drivers for AMD High Definition Audio Device
Add drivers for REINER SCT cyberJack e-com(a)/e-com plus/Secoder USB

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Image Version: 10.0.22631.2861

Found 19 driver package(s) to install.
Installing 1 of 19 - D:\ImageFactory\Stefan\work\driver\amdafd.inf_amd64_98939332ba1b458a\amdafd.inf: The driver package was successfully installed.
Installing 2 of 19 - D:\ImageFactory\Stefan\work\driver\amdfendr.inf_amd64_790c3b89d61d232e\amdfendr.inf: The driver package was successfully installed.
Installing 3 of 19 - D:\ImageFactory\Stefan\work\driver\amdgpio2.inf_amd64_26fd146b41c45ce2\amdgpio2.inf: The driver package was successfully installed.
Installing 4 of 19 - D:\ImageFactory\Stefan\work\driver\amdgpio3.inf_amd64_f03ace476a8fec30\amdgpio3.inf: The driver package was successfully installed.
Installing 5 of 19 - D:\ImageFactory\Stefan\work\driver\amdocl.inf_amd64_3f5ad05be848c8d0\amdocl.inf: The driver package was successfully installed.
Installing 6 of 19 - D:\ImageFactory\Stefan\work\driver\amdpcidev.inf_amd64_2dbed7efd5f2b448\amdpcidev.inf: The driver package was successfully installed.
Installing 7 of 19 - D:\ImageFactory\Stefan\work\driver\amdpsp.inf_amd64_3d8eba6178a9a15e\amdpsp.inf: The driver package was successfully installed.
Installing 8 of 19 - D:\ImageFactory\Stefan\work\driver\asussci2.inf_amd64_4fc38a913e0f2ea5\asussci2.inf: The driver package was successfully installed.
Installing 9 of 19 - D:\ImageFactory\Stefan\work\driver\asusswc.inf_amd64_a4fdd01ce4b4de03\asusswc.inf: The driver package was successfully installed.
Installing 10 of 19 - D:\ImageFactory\Stefan\work\driver\atihdwt6.inf_amd64_e054ad64864d19d3\atihdwt6.inf: The driver package was successfully installed.
Installing 11 of 19 - D:\ImageFactory\Stefan\work\driver\ctxhda.inf_amd64_1239ba03e9051498\ctxhda.inf: The driver package was successfully installed.
Installing 12 of 19 - D:\ImageFactory\Stefan\work\driver\cyucmclient.inf_amd64_3d5e258995978aa0\cyucmclient.inf: The driver package was successfully installed.
Installing 13 of 19 - D:\ImageFactory\Stefan\work\driver\dpumdf.inf_amd64_8e23525834f62e28\dpumdf.inf: The driver package was successfully installed.
Installing 14 of 19 - D:\ImageFactory\Stefan\work\driver\e2f.inf_amd64_2d5cb0c750512550\e2f.inf: The driver package was successfully installed.
Installing 15 of 19 - D:\ImageFactory\Stefan\work\driver\lgsusb.inf_amd64_c6a29e4cd588cf6a\lgsusb.inf: The driver package was successfully installed.
Installing 16 of 19 - D:\ImageFactory\Stefan\work\driver\smbusamd.inf_amd64_246caabd058be11f\smbusamd.inf: The driver package was successfully installed.
Installing 17 of 19 - D:\ImageFactory\Stefan\work\driver\tbthostcontroller.inf_amd64_90f6a13df0927823\tbthostcontroller.inf: The driver package was successfully installed.
Installing 18 of 19 - D:\ImageFactory\Stefan\work\driver\tbthostcontrollerhsacomponent.inf_amd64_d31d2cc1c9ebc4c5\tbthostcontrollerhsacomponent.inf: The driver package was successfully installed.
Installing 19 of 19 - D:\ImageFactory\Stefan\work\driver\u0396906.inf_amd64_85a7dd2e12f92c85\u0396906.inf: The driver package was successfully installed.
The operation completed successfully.
Installing drivers ... DONE

Customize registry settings
===========================

Loading SYSTEM registry
Setting time to UTC
Disable MS Edge First Run Experience
Disable MS Edge SmartScreen
Disable MS Edge SmartScreen DNS
Disable Typeosquatting Checker
Disable keep apps running after close
Configure DNT (Do Not Track) for Edge
Do not ask users to switch to Edge
Disable Cloud Sync
Disable first run experience
Disable Defender Cloud
Disable Defender Submit Samples to Microsoft
Change AllJoyn-Routerdienst from Manual to Disabled
Change AMD Crash Defender Service from Automatic to Disabled
Change ASUS App Service from Automatic to Disabled
Change ASUS Link Near from Automatic to Disabled
Change ASUS Link Remote from Automatic to Disabled
Change ASUS Optimization from Automatic to Disabled
Change ASUS Software Manager from Automatic to Disabled
Change ASUS Switch from Automatic to Disabled
Change ASUS System Diagnosis from Automatic to Disabled
Change Mobilfunkzeit from Manual to Disabled
Change Microsoft-Cloudidentitaetsdienst from Manual to Disabled
Change Standardsammlungsdienst des Microsoft(R)-Diagnose-Hubs from Manual to Disabled
Change Benutzererfahrungen und Telemetrie im verbundenen Modus from Automatic to Disabled
Change WAP-Push-Nachrichten Routing-Dienst (Wireless Application Protocol) fuer die Geraeteverwaltung from Manual to Disabled
Change Automatische Konfiguration (verkabelt) from Manual to Disabled
Change HV-Hostdienst from Manual to Disabled
Change Windows-Dienst fuer mobile Hotspots from Manual to Disabled
Change TCP/IP-NetBIOS-Hilfsdienst from Manual to Disabled
Change Microsoft iSCSI-Initiator-Dienst from Manual to Disabled
Change Programmkompatibilitaets-Assistent-Dienst from Automatic to Disabled
Change Telefondienst from Manual to Disabled
Change Windows PushToInstall-Dienst from Manual to Disabled
Change Dienst fuer Einzelhandelsdemos from Manual to Disabled
Change Richtlinie zum Entfernen der Scmartcard from Manual to Disabled
Change Zahlungs- und NFC/SE-Manager from Manual to Disabled
Change Shellhardwareerkennung from Automatic to Disabled
Change Windows Perception Service from Manual to Disabled
Change Telefonie from Manual to Disabled
Change Hyper-V-Gastdienstschnittstelle from Manual to Disabled
Change Hyper-V-Taktdienst from Manual to Disabled
Change Hyper-V-Datenaustauschdienst from Manual to Disabled
Change Hyper-V-Remotedesktopvirtualisierungsdienst from Manual to Disabled
Change Hyper-V-Dienst zum Herunterfahren des Gasts from Manual to Disabled
Change Hyper-V-Dienst fuer Zeitsynchronisierung from Manual to Disabled
Change Hyper-V PowerShell Direct-Dienst from Manual to Disabled
Change Hyper-V-Volumeschattenkopie-Anforderer from Manual to Disabled
Change WalletService from Manual to Disabled
Change Windows-Biometriedienst from Manual to Disabled
Change Windows-Insider-Dienst from Manual to Disabled
Change Automatische WLAN-Konfiguration from Manual to Disabled
Change Anmelde-Assistent fuer Microsoft-Konten from Manual to Disabled
Change Jugendschutz from Manual to Disabled
Change Windows Search from Automatic to Disabled
Change Xbox Live Authentifizierungs-Manager from Manual to Disabled
Change Xbox Live-Spiele speichern from Manual to Disabled
Change Xbox Accessory Management Service from Manual to Disabled
Change Xbox Live-Netzwerkservice from Manual to Disabled
Unloading SYSTEM registry

Customize registry settings for new users
=========================================

Load registry
Disable content delivery manager
Enable Search in Taskbar
Show file extensions
Show hidden files
Disable Chat Icon in Taskbar
Disable Widgets
Disable SmartScreen
Disable Windows personalized ADs
Disable Communication with unpaired devices
Disable autostarting closed apps
Disable OneDrive Setup on login
Unload registry
Rename Windows\System32\OneDriveSetup.exe to Windows\System32\OneDriveSetup.backup
Adding Windows\System32\OneDriveSetup.backup.txt for instructions to reenable

Import local group policies


LGPO.exe - Local Group Policy Object Utility
Version 3.0.2004.13001
Copyright (C) 2015-2020 Microsoft Corporation
Security Compliance Toolkit - https://www.microsoft.com/download/details.aspx?id=55319

Build registry.pol file "work\mnt\Windows\System32\GroupPolicy\Machine\Registry.pol" from input file "lgpo.m.txt"

LGPO.exe - Local Group Policy Object Utility
Version 3.0.2004.13001
Copyright (C) 2015-2020 Microsoft Corporation
Security Compliance Toolkit - https://www.microsoft.com/download/details.aspx?id=55319

Build registry.pol file "work\mnt\Windows\System32\GroupPolicy\User\Registry.pol" from input file "lgpo.u.txt"

Add our transport truck directory
=================================


Finalizing Image
================

AnalyzeComponentStore

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Image Version: 10.0.22631.2861

[==========================100.0%==========================]

Component Store (WinSxS) information:

Windows Explorer Reported Size of Component Store : 13.42 GB

Actual Size of Component Store : 12.84 GB

    Shared with Windows : 6.34 GB
    Backups and Disabled Features : 6.49 GB
    Cache and Temporary Data :  0 bytes

Date of Last Cleanup : 2023-10-01 08:07:03

Number of Reclaimable Packages : 0
Component Store Cleanup Recommended : Yes

The operation completed successfully.

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Image Version: 10.0.22631.2861

[=====                      10.0%                          ]

[===========================97.0%========================  ]
The operation completed successfully.

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Image Version: 10.0.22631.2861

[==========================100.0%==========================] No component store corruption detected.
The operation completed successfully.

Deployment Image Servicing and Management tool
Version: 10.0.25398.1

Image Version: 10.0.22631.2861

No component store corruption detected.
The operation completed successfully.
Unmount image
Preparing our new ISO ...
Extracting image to ISO
Copy Autounattend.xml into image
        1 Datei(en) kopiert.
Create new ISO

OSCDIMG 2.56 CD-ROM and DVD-ROM Premastering Utility
Copyright (C) Microsoft, 1993-2012. All rights reserved.
Licensed only for producing Microsoft authorized content.


Scanning source tree (500 files in 43 directories)
Scanning source tree complete (946 files in 86 directories)

Computing directory information complete

Image file is 6660161536 bytes (before optimization)

Writing 946 files in 86 directories to Windows_11_Pro_Custom.iso

100% complete

Storage optimization saved 3 files, 18432 bytes (0% of image)

After optimization, image file is 6662234112 bytes
Space saved because of embedding, sparseness or optimization = 18432

Done.

Finished
========

You can now install your personal Windows 11 Pro by using

    D:\ImageFactory\Stefan\Windows_11_Pro_Custom.iso

If you want to install your system via USB use a tool like rufus

    https://rufus.ie

but make sure you disable the creation of an unattendedd file to not overwrite
our efforts.

You can also remove the work directory now.

    RD /S work


D:\ImageFactory\Stefan>
```

[Win11]: https://www.microsoft.com/en-us/software-download/windows11
[CAT]: https://catalog.update.microsoft.com
[KB5033375]: https://catalog.update.microsoft.com/Search.aspx?q=Cumulative%20Update%20for%20Windows%2011%20Version%2023H2%20for%20x64-based%20Systems
[ADK]: https://go.microsoft.com/fwlink/?linkid=2243390
[LGPO]: https://www.microsoft.com/en-us/download/details.aspx?id=55319
[RUFUS]: https://rufus.ie
[ZIP]: https://7-zip.org/
