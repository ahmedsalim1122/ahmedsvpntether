@echo off
REM deploy_tweak.bat - Upload tweak source to iPhone and build
echo === AhmedVPN Tether Deploy ===
echo.

set SSH_HOST=127.0.0.1
set SSH_PORT=2222
set SSH_USER=root
set SSH_PASS=1
set HOSTKEY=ssh-ed25519 255 SHA256:HnbhRBFGb0OsGjXDH/DpJZWpDrq5jsQyxzGTJ30MrgI
set IPROXY=C:\Users\ahmed\AppData\Local\Temp\libimobile\iproxy.exe

echo [1/3] Starting iproxy...
taskkill /F /IM iproxy.exe >nul 2>&1
start "" "%IPROXY%" 2222 22
timeout /t 2 /nobreak >nul

echo [2/3] Uploading tweak source...
pscp -P %SSH_PORT% -pw %SSH_PASS% -hostkey %HOSTKEY% -r ^
    "E:\vpn-ios-tether\tweak\DEBIAN" %SSH_USER%@%SSH_HOST%:/tmp/vpntether_source/
pscp -P %SSH_PORT% -pw %SSH_PASS% -hostkey %HOSTKEY% -r ^
    "E:\vpn-ios-tether\tweak\Library" %SSH_USER%@%SSH_HOST%:/tmp/vpntether_source/
pscp -P %SSH_PORT% -pw %SSH_PASS% -hostkey %HOSTKEY% -r ^
    "E:\vpn-ios-tether\tweak\usr" %SSH_USER%@%SSH_HOST%:/tmp/vpntether_source/
pscp -P %SSH_PORT% -pw %SSH_PASS% -hostkey %HOSTKEY% ^
    "E:\vpn-ios-tether\tweak\build_tweak.sh" %SSH_USER%@%SSH_HOST%:/tmp/vpntether_source/

echo [3/3] Building .deb on device...
plink -P %SSH_PORT% -pw %SSH_PASS% -hostkey %HOSTKEY% %SSH_USER%@%SSH_HOST% ^
    "chmod +x /tmp/vpntether_source/build_tweak.sh && bash /tmp/vpntether_source/build_tweak.sh"

echo.
echo Done!
pause
