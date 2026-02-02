@echo off
REM Luma - Architectural Visualization Tool
REM ComfyUI Startup Script (Windows / NVIDIA)
REM
REM SECURITY NOTES:
REM - Default binding: 127.0.0.1 (localhost only) for security
REM - Use --network flag to bind to all interfaces (LAN access)
REM - CVE-2025-6092: XSS vulnerability - keep ComfyUI updated
REM - CVE-2026-22777: CRLF injection - use ComfyUI-Manager v3.39.2+

setlocal

echo ================================
echo   Luma - Archviz AI Tool
echo   Starting ComfyUI Server...
echo ================================

REM Get script directory
set SCRIPT_DIR=%~dp0
set COMFYUI_DIR=%SCRIPT_DIR%ComfyUI

REM Default to localhost for security (same as macOS)
set LISTEN_ADDR=127.0.0.1

REM Parse arguments for --network flag
:parse_args
if "%~1"=="" goto done_args
if /i "%~1"=="--network" set LISTEN_ADDR=0.0.0.0
shift
goto parse_args
:done_args

REM Activate conda environment
call conda activate luma
if errorlevel 1 (
    echo ERROR: Failed to activate conda environment 'luma'
    pause
    exit /b 1
)

REM Change to ComfyUI directory
cd /d "%COMFYUI_DIR%"
if errorlevel 1 (
    echo ERROR: ComfyUI directory not found at %COMFYUI_DIR%
    pause
    exit /b 1
)

echo Listening on %LISTEN_ADDR%:8188
if "%LISTEN_ADDR%"=="127.0.0.1" (
    echo Use --network flag to enable LAN access
)

REM Start ComfyUI with CUDA support
python main.py --listen %LISTEN_ADDR% --port 8188 %*

echo ComfyUI server stopped.
pause
endlocal
