@echo off
chcp 65001 >nul 2>&1
setlocal

:: 确保工作目录为脚本所在目录
cd /d "%~dp0"
set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "NODE_BIN=%CLAWSTART_HOME%\runtime\node\node.exe"
set "OPENCLAW_CLI=%CLAWSTART_HOME%\runtime\npm-global\lib\node_modules\openclaw\openclaw.mjs"
set "STATE_DIR=%CLAWSTART_HOME%\state"
set "CONFIG_FILE=%STATE_DIR%\openclaw.json"
set "WORKSPACE_DIR=%CLAWSTART_HOME%\workspace"

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"
if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"

set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%CONFIG_FILE%"
set "OPENCLAW_HOME=%CLAWSTART_HOME%"
set "PATH=%CLAWSTART_HOME%\runtime\node;%PATH%"

if not exist "%NODE_BIN%" (
    echo [错误] 未找到内嵌 Node.js: %NODE_BIN%
    echo 请确认在一键包目录下运行，或重新下载完整的一键包。
    pause
    exit /b 1
)
if not exist "%OPENCLAW_CLI%" (
    echo [错误] 未找到 OpenClaw CLI: %OPENCLAW_CLI%
    echo 请确认在一键包目录下运行，或重新下载完整的一键包。
    pause
    exit /b 1
)

echo.
echo   ClawStart 首次配置
echo   接下来会打开 OpenClaw 的配置向导。
echo.

"%NODE_BIN%" "%OPENCLAW_CLI%" setup --wizard --mode local --workspace "%WORKSPACE_DIR%"
if errorlevel 1 (
    echo.
    echo [错误] OpenClaw 配置向导未完成
    pause
    exit /b 1
)

echo.
echo OK 配置完成
exit /b 0
