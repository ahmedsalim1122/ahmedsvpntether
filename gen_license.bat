@echo off
REM gen_license.bat - Generate license keys for AhmedVPN Tether
echo === AhmedVPN Tether License Generator ===
echo.

setlocal EnableDelayedExpansion

:generate
set "chars=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
set "key=VPNT-"

for /L %%i in (1,1,4) do (
    set /a "rand=!random! %% 36"
    set "key=!key!!chars:~!rand!,1!"
)
set "key=!key!-"

for /L %%i in (1,1,4) do (
    set /a "rand=!random! %% 36"
    set "key=!key!!chars:~!rand!,1!"
)
set "key=!key!-"

for /L %%i in (1,1,4) do (
    set /a "rand=!random! %% 36"
    set "key=!key!!chars:~!rand!,1!"
)

echo License Key: !key!
echo.
echo To activate on device:
echo   vpntether_manager activate !key!
echo.

set /p "another=Generate another? (y/n): "
if /i "%another%"=="y" goto generate

endlocal
pause
