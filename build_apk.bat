@echo off
echo Building Smart Home APK with WiFi and Mobile Data support...

REM Clean previous builds
echo Cleaning previous builds...
flutter clean

REM Get dependencies
echo Getting dependencies...
flutter pub get

REM Build APK with network support
echo Building APK...
flutter build apk --release --target-platform android-arm,android-arm64,android-x64

REM Check if build was successful
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ APK built successfully!
    echo 📱 APK location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo 🔧 Features included:
    echo   - WiFi connectivity support
    echo   - Mobile data connectivity support
    echo   - Network security configuration
    echo   - Cleartext traffic support
    echo   - Automatic network detection
    echo   - Smart retry mechanism
    echo.
    echo 📋 Installation notes:
    echo   - Install on Android device
    echo   - Grant network permissions when prompted
    echo   - App will work on both WiFi and mobile data
    echo   - Network status indicator shows connection type
    echo.
) else (
    echo.
    echo ❌ Build failed! Check the error messages above.
    echo.
)

pause
