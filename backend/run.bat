@echo off
echo ===================================================
echo 🔮 Launching Lumina AI Translator Platform 🔮
echo ===================================================

echo 1. Starting Python API Backend Server...
start "" cmd /k python "%~dp0api.py"

echo 2. Waiting for backend to initialize...
timeout /t 3 /nobreak > nul

echo 3. Launching Flutter Frontend UI...
cd /d "%~dp0..\ai_translator"
flutter run
