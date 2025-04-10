@echo off
REM Build script for BeenScanCuda on Windows with CUDA 12.6

REM Set CUDA path - modify as needed for your system
set CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6

REM Check if CUDA path exists
if not exist "%CUDA_PATH%" (
    echo CUDA 12.6 not found at %CUDA_PATH%
    echo Please edit this script to set the correct CUDA path
    exit /b 1
)

echo Building BeenScanCuda with CUDA 12.6...
echo CUDA path: %CUDA_PATH%

REM Check if Visual Studio is installed and set up
where cl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Visual Studio compiler not found in path.
    echo Please run this from a Visual Studio Developer Command Prompt
    exit /b 1
)

REM Build using MSBuild and the updated CUDA 12.6 project
MSBuild BeenScanCuda12_6.sln /p:Configuration=Release /p:Platform=x64

if %ERRORLEVEL% neq 0 (
    echo Build failed!
    exit /b 1
)

echo Build completed successfully!
echo The executable is located in x64\Release\BeenScanCuda.exe 