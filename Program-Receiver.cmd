@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ise-vm.ps1 -Action ReceiverProgram
pause
