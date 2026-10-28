@echo off
setlocal EnableDelayedExpansion
title XAMPP MySQL Repair

REM ===== CHANGE THIS if XAMPP is installed somewhere else =====
set "XAMPP=C:\xampp"
REM ============================================================

set "DATA=%XAMPP%\mysql\data"
set "BACKUPSRC=%XAMPP%\mysql\backup"

REM ---- Must run as Administrator ----
net session >nul 2>&1
if errorlevel 1 (
    echo [!] Please right-click this file and choose "Run as administrator".
    pause
    exit /b 1
)

if not exist "%DATA%" (
    echo [!] Could not find %DATA%
    echo     Edit the XAMPP path at the top of this script.
    pause
    exit /b 1
)

REM ---- Timestamp for backup folder names ----
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%i"
set "SAFE=%XAMPP%\mysql_data_safety_copy_%TS%"

echo ==============================================
echo   XAMPP MySQL Repair
echo ==============================================
echo   1. Quick fix  (delete ib_logfile / aria_log files)
echo   2. Full repair (rebuild data folder, keep your databases)
echo   Q. Quit
echo ==============================================
choice /C 12Q /N /M "Choose an option [1/2/Q]: "
if errorlevel 3 exit /b 0
if errorlevel 2 goto FULL
if errorlevel 1 goto QUICK

REM =====================================================
:QUICK
call :STOPMYSQL
call :SAFETYCOPY || goto FAIL

echo.
echo [*] Deleting InnoDB / Aria log files...
del /F /Q "%DATA%\ib_logfile0" 2>nul
del /F /Q "%DATA%\ib_logfile1" 2>nul
del /F /Q "%DATA%\aria_log.*" 2>nul
del /F /Q "%DATA%\aria_log_control" 2>nul

echo.
echo [OK] Quick fix done. Now start MySQL from the XAMPP Control Panel.
echo      If it still fails, run this script again and choose option 2.
echo      Safety copy: %SAFE%
pause
exit /b 0

REM =====================================================
:FULL
if not exist "%BACKUPSRC%" (
    echo [!] %BACKUPSRC% not found. Cannot do a full repair.
    pause
    exit /b 1
)

call :STOPMYSQL
call :SAFETYCOPY || goto FAIL

set "OLD=data_old_%TS%"

echo.
echo [*] Renaming data folder to %OLD% ...
ren "%DATA%" "%OLD%"
if errorlevel 1 goto FAIL

echo [*] Creating fresh data folder from XAMPP backup...
robocopy "%BACKUPSRC%" "%DATA%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto FAIL

echo [*] Restoring your own databases...
for /d %%D in ("%XAMPP%\mysql\%OLD%\*") do (
    set "NAME=%%~nxD"
    set "SKIP="
    for %%S in (mysql performance_schema phpmyadmin sys test) do (
        if /I "!NAME!"=="%%S" set "SKIP=1"
    )
    if not defined SKIP (
        echo     - !NAME!
        robocopy "%%D" "%DATA%\!NAME!" /E /NFL /NDL /NJH /NJS /NP >nul
    )
)

echo [*] Restoring ibdata1...
copy /Y "%XAMPP%\mysql\%OLD%\ibdata1" "%DATA%\ibdata1" >nul

echo.
echo [OK] Full repair done. Now start MySQL from the XAMPP Control Panel.
echo      Old data folder : %XAMPP%\mysql\%OLD%
echo      Safety copy     : %SAFE%
echo      Keep both until you confirm all your databases work.
pause
exit /b 0

REM =====================================================
:STOPMYSQL
echo.
echo [*] Stopping any leftover MySQL process...
taskkill /F /IM mysqld.exe >nul 2>&1
timeout /t 2 /nobreak >nul
exit /b 0

:SAFETYCOPY
echo [*] Making safety copy of data folder...
echo     %SAFE%
robocopy "%DATA%" "%SAFE%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 exit /b 1
echo [OK] Safety copy created.
exit /b 0

:FAIL
echo.
echo [!] Something went wrong. Nothing further was changed.
echo     Your safety copy (if created): %SAFE%
pause
exit /b 1
