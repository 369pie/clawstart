@echo off
chcp 65001 >nul 2>&1
setlocal

set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "NODE_BIN=%CLAWSTART_HOME%\runtime\node\node.exe"
set "OPENCLAW_CLI=%CLAWSTART_HOME%\runtime\npm-global\node_modules\openclaw\openclaw.mjs"
set "STATE_DIR=%CLAWSTART_HOME%\state"
set "CONFIG_FILE=%STATE_DIR%\openclaw.json"
set "WORKSPACE_DIR=%CLAWSTART_HOME%\workspace"

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"
if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"

set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%CONFIG_FILE%"
set "OPENCLAW_HOME=%CLAWSTART_HOME%"

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
