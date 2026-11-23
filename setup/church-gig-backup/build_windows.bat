@echo off
REM MIDIFlow Windows Build Script
REM Run this on a Windows machine to build the Windows installer

echo =========================================
echo MIDIFlow Windows Build Script
echo =========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed.
    echo Install from: https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

REM Navigate to project directory
cd /d "%~dp0.."

echo [1/5] Cleaning previous builds...
flutter clean

echo [2/5] Getting dependencies...
flutter pub get

echo [3/5] Building Windows release...
flutter build windows --release

echo [4/5] Packaging...
if not exist "setup\app-installers\windows" mkdir "setup\app-installers\windows"

REM Copy the built files
xcopy /E /I /Y "build\windows\x64\runner\Release\*" "setup\app-installers\windows\MIDIFlow\"

REM Create zip file
powershell -Command "Compress-Archive -Path 'setup\app-installers\windows\MIDIFlow\*' -DestinationPath 'setup\app-installers\windows\MIDIFlow-windows.zip' -Force"

echo [5/5] Done!
echo.
echo Windows installer created at:
echo setup\app-installers\windows\MIDIFlow-windows.zip
echo.
pause
