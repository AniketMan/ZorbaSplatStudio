@echo off
:: package_release.bat
:: Creates a distributable release package (ZIP) of ZORBA Splat Studio.
:: The package includes the EXE, DLLs, resources, and documentation.

setlocal enabledelayedexpansion

echo ============================================================
echo  ZORBA Splat Studio - Package Release
echo ============================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"
set "RELEASE_DIR=%SCRIPT_DIR%release"

:: --- Get version from user or default ---

set "VERSION=%~1"
if "%VERSION%"=="" (
    set /p VERSION="Enter version number (e.g., 1.0.0): "
)
if "%VERSION%"=="" (
    set "VERSION=dev"
)

set "PACKAGE_NAME=ZorbaSplatStudio-v%VERSION%-win64"
set "PACKAGE_DIR=%RELEASE_DIR%\%PACKAGE_NAME%"

echo Package: %PACKAGE_NAME%
echo.

:: --- Check if build exists ---

if not exist "%BUILD_DIR%\LichtFeld-Studio.exe" (
    if not exist "%BUILD_DIR%\Release\LichtFeld-Studio.exe" (
        echo ERROR: Build not found. Run build_zorba.bat first.
        pause
        exit /b 1
    )
)

:: --- Determine source directory ---

if exist "%BUILD_DIR%\LichtFeld-Studio.exe" (
    set "BIN_DIR=%BUILD_DIR%"
) else (
    set "BIN_DIR=%BUILD_DIR%\Release"
)

:: --- Create release directory ---

echo [1/6] Creating release directory...
if exist "%PACKAGE_DIR%" rmdir /S /Q "%PACKAGE_DIR%"
mkdir "%PACKAGE_DIR%"
mkdir "%PACKAGE_DIR%\bin"
echo.

:: --- Copy executable ---

echo [2/6] Copying executable...
copy /Y "%BIN_DIR%\LichtFeld-Studio.exe" "%PACKAGE_DIR%\bin\ZorbaSplatStudio.exe" >nul
echo   Copied: ZorbaSplatStudio.exe
echo.

:: --- Copy DLLs ---

echo [3/6] Copying runtime libraries...
for %%f in ("%BIN_DIR%\*.dll") do (
    copy /Y "%%f" "%PACKAGE_DIR%\bin\" >nul
    echo   Copied: %%~nxf
)
echo.

:: --- Copy resources ---

echo [4/6] Copying resources...
if exist "%SCRIPT_DIR%resources" (
    xcopy /E /Y /Q "%SCRIPT_DIR%resources" "%PACKAGE_DIR%\resources\" >nul
    echo   Copied: resources\
)
if exist "%BIN_DIR%\shaders" (
    xcopy /E /Y /Q "%BIN_DIR%\shaders" "%PACKAGE_DIR%\bin\shaders\" >nul
    echo   Copied: shaders\
)
echo.

:: --- Copy documentation ---

echo [5/6] Copying documentation...
if exist "%SCRIPT_DIR%README.md" (
    copy /Y "%SCRIPT_DIR%README.md" "%PACKAGE_DIR%\" >nul
    echo   Copied: README.md
)
if exist "%SCRIPT_DIR%LICENSE" (
    copy /Y "%SCRIPT_DIR%LICENSE" "%PACKAGE_DIR%\" >nul
    echo   Copied: LICENSE
)
if exist "%SCRIPT_DIR%THIRD_PARTY_LICENSES.md" (
    copy /Y "%SCRIPT_DIR%THIRD_PARTY_LICENSES.md" "%PACKAGE_DIR%\" >nul
    echo   Copied: THIRD_PARTY_LICENSES.md
)

:: Create a quick-start script
(
echo @echo off
echo :: Quick launcher for ZORBA Splat Studio
echo cd /d "%%~dp0bin"
echo start ZorbaSplatStudio.exe %%*
) > "%PACKAGE_DIR%\Launch.bat"
echo   Created: Launch.bat
echo.

:: --- Create ZIP archive ---

echo [6/6] Creating ZIP archive...
set "ZIP_PATH=%RELEASE_DIR%\%PACKAGE_NAME%.zip"

if exist "%ZIP_PATH%" del "%ZIP_PATH%"

powershell -NoProfile -Command ^
    "Compress-Archive -Path '%PACKAGE_DIR%\*' -DestinationPath '%ZIP_PATH%' -Force"

if %errorLevel% equ 0 (
    echo   Created: %ZIP_PATH%
) else (
    echo   ERROR: Failed to create ZIP archive.
    echo   Package directory is still available at: %PACKAGE_DIR%
)

echo.
echo ============================================================
echo  Release Package Created!
echo.
echo  Directory: %PACKAGE_DIR%
echo  Archive:   %ZIP_PATH%
echo.
echo  Contents:
echo    bin\ZorbaSplatStudio.exe  - Main executable
echo    bin\*.dll                 - Runtime libraries
echo    bin\shaders\              - GPU shaders
echo    resources\                - Application resources
echo    README.md                 - Documentation
echo    LICENSE                   - License information
echo    Launch.bat                - Quick launcher script
echo ============================================================

pause
