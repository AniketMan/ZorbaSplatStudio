@echo off
:: get_latest.bat
:: Pulls the latest version from git and rebuilds ZORBA Splat Studio.

setlocal enabledelayedexpansion

echo ============================================================
echo  ZORBA Splat Studio - Get Latest
echo ============================================================
echo.

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: --- Check git ---

where git >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Git not found in PATH.
    pause
    exit /b 1
)

:: --- Stash local changes ---

echo [1/5] Checking for local changes...
git diff --quiet --exit-code
if %errorLevel% neq 0 (
    echo   Local changes detected. Stashing...
    git stash push -m "get_latest auto-stash %date% %time%"
    set "STASHED=1"
) else (
    echo   No local changes.
    set "STASHED=0"
)
echo.

:: --- Fetch and pull ---

echo [2/5] Fetching from remote...
git fetch origin
if %errorLevel% neq 0 (
    echo ERROR: Failed to fetch from remote.
    pause
    exit /b 1
)
echo.

echo [3/5] Pulling latest changes...
git pull origin main
if %errorLevel% neq 0 (
    echo WARNING: Pull failed. Trying to pull from master branch...
    git pull origin master
    if %errorLevel% neq 0 (
        echo ERROR: Failed to pull from both main and master branches.
        pause
        exit /b 1
    )
)
echo.

:: --- Update submodules ---

echo [4/5] Updating submodules...
git submodule update --init --recursive
if %errorLevel% neq 0 (
    echo WARNING: Submodule update had issues, but continuing...
)
echo.

:: --- Rebuild ---

echo [5/5] Rebuilding...
echo.
call "%SCRIPT_DIR%build_zorba.bat"

:: --- Restore stashed changes ---

if "%STASHED%"=="1" (
    echo.
    echo Restoring stashed changes...
    git stash pop
    if %errorLevel% neq 0 (
        echo WARNING: Could not restore stashed changes automatically.
        echo Run 'git stash list' and 'git stash pop' manually if needed.
    )
)

echo.
echo ============================================================
echo  Get Latest complete!
echo ============================================================

pause
