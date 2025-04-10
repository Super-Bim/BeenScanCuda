@echo off
REM Build script for VanitySearch on Windows with CUDA 12.6+

REM Try to detect CUDA path automatically
set "CUDA_FOUND=0"
set "CUDA_PATH="

REM Check for CUDA 12.8 first
if exist "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8" (
    set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
    set "CUDA_FOUND=1"
    echo Found CUDA 12.8
    goto cuda_found
)

REM Check for CUDA 12.6
if exist "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6" (
    set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
    set "CUDA_FOUND=1"
    echo Found CUDA 12.6
    goto cuda_found
)

REM Check for newer versions (for future compatibility)
for /f "delims=" %%i in ('dir "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v*" /b /ad 2^>nul') do (
    set "LATEST_CUDA=%%i"
    set "CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\%%i"
    set "CUDA_FOUND=1"
    echo Found CUDA %%i
)

:cuda_found
if "%CUDA_FOUND%"=="0" (
    echo CUDA 12.6 or newer not found.
    echo Please install CUDA 12.6 or newer from https://developer.nvidia.com/cuda-downloads
    exit /b 1
)

echo Building VanitySearch with CUDA %CUDA_PATH%...

REM Check if Visual Studio is installed and set up
where cl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Visual Studio compiler not found in path.
    echo Please run this from a Visual Studio Developer Command Prompt
    exit /b 1
)

REM Build using MSBuild and the CUDA project
MSBuild VanitySearchCUDA12_6.sln /p:Configuration=Release /p:Platform=x64

if %ERRORLEVEL% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build completed successfully!
echo The executable is located in x64\Release\VanitySearchCUDA12_6.exe 