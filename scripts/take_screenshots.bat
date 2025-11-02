@echo off
REM Flutter App Screenshot Capture Script for Windows
REM This script automates taking screenshots of the Flutter application on physical devices

echo 📸 Flutter App Screenshot Capture
echo ==================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Check if ADB is available (needed for physical devices)
where adb >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️  ADB not found in PATH. Screenshot retrieval may not work.
    echo    Make sure Android SDK platform-tools are in your PATH
    echo.
)

REM Get device list
echo 📱 Checking connected devices...
echo.

REM Store device list in a temporary file
flutter devices > temp_devices.txt

REM Check if any devices are connected
findstr /C:"No devices found" temp_devices.txt >nul
if %ERRORLEVEL% EQU 0 (
    echo ❌ No devices found! Please connect a device or start an emulator.
    del temp_devices.txt 2>nul
    pause
    exit /b 1
)

REM Display devices
echo Available devices:
echo ========================================
type temp_devices.txt
echo ========================================
echo.

REM Enable delayed expansion for device parsing
setlocal enabledelayedexpansion

REM Parse devices into array and display menu simultaneously
set device_num=0
echo Device Selection Menu:
echo ========================================

REM Parse devices and build menu, storing device IDs
for /f "tokens=*" %%i in (temp_devices.txt) do (
    echo %%i | findstr /C:"•" >nul
    if !ERRORLEVEL! EQU 0 (
        set /a device_num+=1
        REM Extract device ID (second token) and display
        for /f "tokens=2*" %%j in ("%%i") do (
            set "device_id_!device_num!=%%j"
            echo   [!device_num!] %%j %%k
        )
    )
)

echo   [0] Use default device ^(first available^)
echo ========================================
echo.

REM Clean up temp file before prompt
del temp_devices.txt 2>nul

REM Prompt for selection
set /p selection="Select device number [0-%device_num%]: "

REM Handle selection
set selected_device=
if "!selection!"=="" set selection=0

if "!selection!"=="0" (
    echo Using default device...
    set selected_device=
) else (
    REM Validate selection is a number
    echo !selection! | findstr /R "^[0-9][0-9]*$" >nul
    if !ERRORLEVEL! EQU 0 (
        REM Check if selection is in valid range
        if !selection! LEQ !device_num! (
            if !selection! GEQ 1 (
                REM Get device ID using indirect variable reference
                call set "selected_device=%%device_id_!selection!%%"
                if "!selected_device!"=="" (
                    echo ❌ Could not find device! Using default device.
                    set selected_device=
                ) else (
                    echo Selected device: !selected_device!
                )
            ) else (
                echo ❌ Selection out of range! Using default device.
                set selected_device=
            )
        ) else (
            echo ❌ Selection out of range! Using default device.
            set selected_device=
        )
    ) else (
        echo ❌ Invalid input! Using default device.
        set selected_device=
    )
)

REM Pass selected_device to outer scope (correct batch scoping technique)
for /f "delims=" %%a in ("!selected_device!") do (
    endlocal
    set "selected_device=%%a"
)

REM Create local screenshots directory
if not exist "screenshots" mkdir screenshots

REM Run screenshot test
echo.
echo 🔄 Running screenshot tests...
echo ========================================
echo.

if "%selected_device%"=="" (
    echo Using default device...
    flutter test integration_test/screenshot_test.dart
) else (
    echo Using device: %selected_device%
    flutter test integration_test/screenshot_test.dart --device-id "%selected_device%"
)

set TEST_RESULT=%ERRORLEVEL%

echo.
echo ========================================
echo.

REM Try to retrieve screenshots from device if test succeeded
if %TEST_RESULT% EQU 0 (
    echo 🔄 Attempting to retrieve screenshots from device...
    echo.
    
        REM Get device serial number from flutter devices or adb
        REM Try to get the first connected device
        for /f "tokens=2" %%i in ('flutter devices ^| findstr "•" ^| findstr /V "emulator"') do (
            set DEVICE_SERIAL=%%i
            goto :found_device_flutter
        )
        
        :found_device_flutter
        REM If not found from flutter, try adb directly
        if not defined DEVICE_SERIAL (
            for /f "skip=1 tokens=1" %%i in ('adb devices') do (
                if not "%%i"=="" (
                    set DEVICE_SERIAL=%%i
                    goto :found_device
                )
            )
        )
        
        :found_device
        if defined DEVICE_SERIAL (
            echo Found device: %DEVICE_SERIAL%
            echo.
            echo 📱 Screenshots Location Information:
            echo    Integration test screenshots are saved by Flutter framework.
            echo    They are typically stored in:
            echo    1. Test output: build\app\outputs\flutter-apk\
            echo    2. Device internal storage (app-specific directory)
            echo.
            echo    To find screenshots on the device, check:
            echo    - Files app ^(Android^)
            echo    - Gallery app for screenshots
            echo    - Test output folder in build directory
            echo.
            echo    To manually retrieve using ADB, try:
            echo    adb pull /data/data/com.codeink.stsl.carcollection/files screenshots/
            echo    or
            echo    adb pull /storage/emulated/0/Android/data/com.codeink.stsl.carcollection/files screenshots/
            echo.
        ) else (
            echo ℹ️  Device information not available, but test completed.
            echo    Check the build output directory for screenshots.
        )
    
    echo ✅ Screenshot test completed successfully!
    echo.
    echo 📁 Local screenshots directory: screenshots\
    echo    (Check if any screenshots were copied here)
    echo.
    
    if exist "screenshots\*.png" (
        echo Found local screenshots:
        dir /b screenshots\*.png
    ) else (
        echo ℹ️  Screenshots are on the device. Use adb to retrieve them.
    )
) else (
    echo ❌ Screenshot test failed with error code: %TEST_RESULT%
    echo    Please check the error messages above.
)

echo.
pause

