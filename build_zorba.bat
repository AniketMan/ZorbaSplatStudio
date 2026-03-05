@echo off
:: build_zorba.bat
:: Builds ZORBA Splat Studio from source on Windows.
:: Output binary is placed in the build\ directory alongside this script.
:: Requires: Visual Studio 2022, CUDA 12.8+, CMake 3.30+, Git, vcpkg

setlocal enabledelayedexpansion

echo ============================================================
echo  ZORBA Splat Studio - Build from Source
echo ============================================================
echo.

:: --- Check prerequisites ---

echo [1/7] Checking prerequisites...

where cmake >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: CMake not found. Install CMake 3.30+ and add it to PATH.
    echo Download: https://cmake.org/download/
    pause
    exit /b 1
)

where git >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Git not found. Install Git and add it to PATH.
    echo Download: https://git-scm.com/downloads
    pause
    exit /b 1
)

where nvcc >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: CUDA toolkit not found. Install CUDA 12.8+ and add nvcc to PATH.
    echo Download: https://developer.nvidia.com/cuda-downloads
    pause
    exit /b 1
)

:: Check VCPKG_ROOT
if "%VCPKG_ROOT%"=="" (
    echo ERROR: VCPKG_ROOT environment variable is not set.
    echo Install vcpkg and set VCPKG_ROOT to the installation directory.
    echo Instructions: https://vcpkg.io/en/getting-started
    pause
    exit /b 1
)

if not exist "%VCPKG_ROOT%\vcpkg.exe" (
    echo ERROR: vcpkg.exe not found at VCPKG_ROOT: %VCPKG_ROOT%
    echo Verify your vcpkg installation.
    pause
    exit /b 1
)

echo   CMake:   OK
echo   Git:     OK
echo   CUDA:    OK
echo   vcpkg:   OK
echo.

:: --- Initialize submodules ---

echo [2/7] Initializing git submodules...
git submodule update --init --recursive
if %errorLevel% neq 0 (
    echo ERROR: Failed to initialize git submodules.
    pause
    exit /b 1
)
echo   Submodules: OK
echo.

:: --- Set build directory to be alongside this script ---

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"

echo [3/7] Build directory: %BUILD_DIR%
echo.

:: --- Configure with CMake ---

echo [4/7] Configuring with CMake (Release)...
cmake -B "%BUILD_DIR%" -S "%SCRIPT_DIR%" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -G Ninja ^
    -DCMAKE_TOOLCHAIN_FILE="%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake"

if %errorLevel% neq 0 (
    echo ERROR: CMake configuration failed.
    echo Check the output above for details.
    pause
    exit /b 1
)
echo   Configure: OK
echo.

:: --- Build ---

echo [5/7] Building ZORBA Splat Studio...
cmake --build "%BUILD_DIR%" --config Release -- -j%NUMBER_OF_PROCESSORS%

if %errorLevel% neq 0 (
    echo ERROR: Build failed.
    echo Check the output above for details.
    pause
    exit /b 1
)
echo   Build: OK
echo.

:: --- Verify output ---

echo [6/7] Verifying build output...
if exist "%BUILD_DIR%\LichtFeld-Studio.exe" (
    echo   Executable found: %BUILD_DIR%\LichtFeld-Studio.exe
) else if exist "%BUILD_DIR%\Release\LichtFeld-Studio.exe" (
    echo   Executable found: %BUILD_DIR%\Release\LichtFeld-Studio.exe
) else (
    echo WARNING: Could not locate the built executable.
    echo Check the build directory: %BUILD_DIR%
)
echo.

:: --- Done ---

echo [7/7] Build complete.
echo ============================================================
echo  ZORBA Splat Studio has been built successfully.
echo  Binary location: %BUILD_DIR%
echo.
echo  To train:  LichtFeld-Studio.exe -d /path/to/colmap --output-path output --strategy mcmc
echo  To view:   LichtFeld-Studio.exe --view /path/to/splat.ply
echo ============================================================

pause
