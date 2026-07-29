@echo off
REM gen_license.bat - Generate VPNTether license key from device UUID
REM Usage: gen_license.bat <device-uuid>
REM Example: gen_license.bat 28E24CE2-BA1C-38B1-AC56-C0BE08A077BC

if "%1"=="" (
    echo Usage: %0 ^<device-uuid^>
    echo Example: %0 28E24CE2-BA1C-38B1-AC56-C0BE08A077BC
    exit /b 1
)

setlocal enabledelayedexpansion
set "uuid=%1"
set "secret=VPNTetherSecret2026"
set "keystr=%secret%%uuid%"

powershell -Command "$h=(New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes('%keystr%'));$k='';$h[0..15]|%%{$k+=$_.ToString('x2')};Write-Output $k"
