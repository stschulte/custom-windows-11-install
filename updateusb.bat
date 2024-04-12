@ECHO OFF

REM Use a Custom ISO to update an already existing
REM USB Stick with Windows 11
REM
REM Author: Stefan Schulte <stschulte@posteo.de>
REM Date  : 2023-11-27
REM
REM This script uses the already build custom ISO image
REM and extracts the install.wim from the image to patch
REM an already mounted USB media

SETLOCAL enableDelayedExpansion

for /f %%D in ('wmic LogicalDisk get Caption^, VolumeName ^| find "CCCOMA_X64FRE"') do set DRIVE=%%D

SET TARGET_DIR=%DRIVE%\sources
SET TARGET_WIM=%DRIVE%\sources\install.wim
SET TARGET_UNATTENDED=%DRIVE%\Autounattend.xml
SET ISO=Windows_11_Pro_Custom.iso
SET IMAGEFACTORY_ZIP=%ProgramFiles%\7-Zip\7z.exe

@ECHO Validating environment
@ECHO ======================

IF NOT EXIST "%DRIVE%" GOTO :err_no_drive_found
IF NOT EXIST "%DRIVE%\sources\winsetup.dll" GOTO :err_no_drive_found
@ECHO * USB drive: %DRIVE% (%TARGET_WIM%)

IF NOT EXIST "%ISO%" GOTO :err_no_iso_found
@ECHO * Installation media: %ISO%

IF NOT EXIST "%IMAGEFACTORY_ZIP%" GOTO :err_no_zip
@ECHO * 7zip found: %IMAGEFACTORY_ZIP%

findstr /L ABCD1-EF2G3-4HI5J-KL6MN-OP7QR Autounattend.xml >nul 2>nul
IF %ERRORLEVEL% EQU 0 GOTO :err_product_key_not_changed

findstr /L User001 Autounattend.xml >nul 2>nul
IF %ERRORLEVEL% EQU 0 GOTO :err_user_not_changed

@ECHO.
@ECHO Copy image
@ECHO ==========

@ECHO Updating install.wim on %DRIVE%
IF EXIST "%TARGET_WIM%" DEL "%TARGET_WIM%"
"%IMAGEFACTORY_ZIP%" e -o"%TARGET_DIR%" "%ISO%" sources\install.wim >nul

@ECHO Copy Autounattend.xml into %TARGET_UNATTENDED%
copy /Y Autounattend.xml "%TARGET_UNATTENDED%"

goto :finish

:err_no_zip
@ECHO.
@ECHO Unable to find %IMAGEFACTORY_ZIP%. This script uses 7zip to extract the original
@ECHO ISO file. You can download 7zip from
@ECHO.
@ECHO     https://7-zip.org
@ECHO.
@ECHO Ensure to install it to the default location
goto :finish

:err_no_iso_found
@ECHO.
@ECHO Unable to find the custom ISO file
@ECHO.
@ECHO     %ISO%
@ECHO.
@ECHO Did you create the ISO by running
@ECHO.
@ECHO     build.bat
@ECHO.
@ECHO first?
goto :finish

:err_user_not_changed
@ECHO.
@ECHO It looks like you forgot to adapt the local username in Autounattend.xml that
@ECHO will be created on your new system. Your probably do not want to call the user
@ECHO User001. Open the file
@ECHO.
@ECHO     %~dp0Autounattend.xml
@ECHO.
@ECHO and replace all occurances of User001 with your desired username. This will set
@ECHO the initial password to the same name as your username but you are forced to
@ECHO change it on next login.
goto :finish

:err_product_key_not_changed
@ECHO.
@ECHO It looks like you forgot to adapt your Product Key in Autounattend.xml. The
@ECHO product key that is mentioned in the file "ABCD1-EF2G3-4HI5J-KL6MN-OP7QR" is only
@ECHO for demonstration purpose. Please modify
@ECHO.
@ECHO     %~dp0Autounattend.xml
@ECHO.
@ECHO Search for the string "ABCD1-EF2G3-4HI5J-KL6MN-OP7QR" in the file and replace it
@ECHO with your actual product key
goto :finish

:err_no_drive_found
@ECHO.
@ECHO Unable to find the USB drive that currently holds our installation. Ensure you
@ECHO Have a USB drive plugged in with the expected label of
@ECHO.
@ECHO     CCCOMA_X64FRE_^<LANGUAGE^>_DV9
@ECHO.
@ECHO e.g.
@ECHO.
@ECHO     CCCOMA_X64FRE_DE-DE_DV9
@ECHO     CCCOMA_X64FRE_EN-US_DV9
@ECHO.
goto :finish

:finish
ENDLOCAL
