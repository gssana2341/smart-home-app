@echo off
echo Building Smart Home Web Application...

REM Clean previous builds
echo Cleaning previous builds...
flutter clean

REM Get dependencies
echo Getting dependencies...
flutter pub get

REM Build web application
echo Building web application...
flutter build web --release --web-renderer html

REM Check if build was successful
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Web application built successfully!
    echo 🌐 Web files location: build\web\
    echo.
    echo 🔧 Features included:
    echo   - WiFi and Mobile Data support
    echo   - Real-time device control
    echo   - Voice commands (TTS)
    echo   - Sensor monitoring
    echo   - Chat with AI
    echo   - Automation rules
    echo   - Responsive web design
    echo.
    echo 📋 Deployment options:
    echo   1. Copy build\web\ folder to your web server
    echo   2. Use GitHub Pages, Netlify, or Vercel
    echo   3. Deploy to Firebase Hosting
    echo.
    echo 🚀 To test locally:
    echo   - Open build\web\index.html in browser
    echo   - Or use: python -m http.server 8000
    echo.
) else (
    echo.
    echo ❌ Build failed! Check the error messages above.
    echo.
)

pause
