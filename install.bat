@echo off
:: install.bat
:: Installs ZORBA Splat Studio to a user-specified location or default.
:: This script copies the built executable and required runtime files.

setlocal enabledelayedexpansion

echo ============================================================
echo  ZORBA Splat Studio - Install
echo ============================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"
set "DEFAULT_INSTALL_DIR=%LOCALAPPDATA%\ZorbaSplatStudio"

:: --- Check if build exists ---

if not exist "%BUILD_DIR%\LichtFeld-Studio.exe" (
    if not exist "%BUILD_DIR%\Release\LichtFeld-Studio.exe" (
        echo ERROR: Build not found. Run build_zorba.bat first.
        pause
        exit /b 1
    )
)

:: --- Determine source executable ---

if exist "%BUILD_DIR%\LichtFeld-Studio.exe" (
    set "EXE_SOURCE=%BUILD_DIR%\LichtFeld-Studio.exe"
    set "BIN_DIR=%BUILD_DIR%"
) else (
    set "EXE_SOURCE=%BUILD_DIR%\Release\LichtFeld-Studio.exe"
    set "BIN_DIR=%BUILD_DIR%\Release"
)

:: --- Get install location ---

set "INSTALL_DIR=%~1"
if "%INSTALL_DIR%"=="" (
    set "INSTALL_DIR=%DEFAULT_INSTALL_DIR%"
)

echo Install location: %INSTALL_DIR%
echo.

:: --- Create install directory ---

if not exist "%INSTALL_DIR%" (
    echo Creating install directory...
    mkdir "%INSTALL_DIR%"
    if %errorLevel% neq 0 (
        echo ERROR: Failed to create install directory.
        pause
        exit /b 1
    )
)

:: --- Copy files ---

echo Copying files...

:: Copy executable
copy /Y "%EXE_SOURCE%" "%INSTALL_DIR%\ZorbaSplatStudio.exe" >nul
if %errorLevel% neq 0 (
    echo ERROR: Failed to copy executable.
    pause
    exit /b 1
)
echo   Copied: ZorbaSplatStudio.exe

:: Copy all DLLs from build directory
for %%f in ("%BIN_DIR%\*.dll") do (
    copy /Y "%%f" "%INSTALL_DIR%\" >nul
    echo   Copied: %%~nxf
)

:: Copy resources directory if it exists
if exist "%SCRIPT_DIR%resources" (
    if not exist "%INSTALL_DIR%\resources" mkdir "%INSTALL_DIR%\resources"
    xcopy /E /Y /Q "%SCRIPT_DIR%resources\*" "%INSTALL_DIR%\resources\" >nul
    echo   Copied: resources\
)

:: Copy shaders if they exist in build
if exist "%BIN_DIR%\shaders" (
    if not exist "%INSTALL_DIR%\shaders" mkdir "%INSTALL_DIR%\shaders"
    xcopy /E /Y /Q "%BIN_DIR%\shaders\*" "%INSTALL_DIR%\shaders\" >nul
    echo   Copied: shaders\
)

echo.

:: --- Create Start Menu shortcut ---

echo Creating Start Menu shortcut...
set "SHORTCUT_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "SHORTCUT_PATH=%SHORTCUT_DIR%\ZORBA Splat Studio.lnk"

powershell -NoProfile -Command ^
    "$ws = New-Object -ComObject WScript.Shell; ^
     $shortcut = $ws.CreateShortcut('%SHORTCUT_PATH%'); ^
     $shortcut.TargetPath = '%INSTALL_DIR%\ZorbaSplatStudio.exe'; ^
     $shortcut.WorkingDirectory = '%INSTALL_DIR%'; ^
     $shortcut.Description = 'ZORBA Splat Studio - 3D Gaussian Splatting Trainer'; ^
     $shortcut.Save()"

if %errorLevel% equ 0 (
    echo   Created: Start Menu shortcut
) else (
    echo   Warning: Could not create Start Menu shortcut
)

echo.

:: --- Register PLY file association (optional) ---

echo.
set /p REGISTER_PLY="Register .ply file association? (y/n): "
if /i "%REGISTER_PLY%"=="y" (
    echo Registering .ply file association...
    reg add "HKCU\Software\Classes\.ply" /ve /d "ZorbaSplatStudio.ply" /f >nul 2>&1
    reg add "HKCU\Software\Classes\ZorbaSplatStudio.ply" /ve /d "Gaussian Splat File" /f >nul 2>&1
    reg add "HKCU\Software\Classes\ZorbaSplatStudio.ply\shell\open\command" /ve /d "\"%INSTALL_DIR%\ZorbaSplatStudio.exe\" --view \"%%1\"" /f >nul 2>&1
    echo   Registered .ply file association
)

echo.
echo ============================================================
echo  Installation complete!
echo.
echo  Location: %INSTALL_DIR%
echo  Executable: ZorbaSplatStudio.exe
echo.
echo  To train:  ZorbaSplatStudio.exe -d /path/to/colmap --output-path output
echo  To view:   ZorbaSplatStudio.exe --view /path/to/splat.ply
echo             (or double-click any .ply file if association was registered)
echo ============================================================

pause
