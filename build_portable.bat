@echo off
REM Lancia build_portable.ps1 per creare la build Windows portable.
REM Doppio click oppure: build_portable.bat [-Zip] [-SkipBuild]

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_portable.ps1" %*

echo.
pause
