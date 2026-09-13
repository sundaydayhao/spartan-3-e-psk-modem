@echo off
powershell.exe -NoProfile -File "%~dp0scripts\ise-vm.ps1" -Action Open
if errorlevel 1 pause
