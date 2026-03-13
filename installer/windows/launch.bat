@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

title ClawStart Windows Beta

set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "NODE_BIN=%CLAWSTART_HOME%\runtime\node\node.exe"
set "OPENCLAW_CLI=%CLAWSTART_HOME%\runtime\npm-global\node_modules\openclaw\openclaw.mjs"
set "STATE_DIR=%CLAWSTART_HOME%\state"
set "CONFIG_FILE=%STATE_DIR%\openclaw.json"
set "WORKSPACE_DIR=%CLAWSTART_HOME%\workspace"
set "LOGS_DIR=%CLAWSTART_HOME%\logs"
set "GATEWAY_PORT=3000"

echo.
echo   ClawStart Windows Beta
echo   下载即运行，开箱就能用
echo.

if not exist "%NODE_BIN%" (
    echo [错误] 未找到内嵌 Node.js
    echo 请重新下载完整的一键包
    goto :error_exit
)

if not exist "%OPENCLAW_CLI%" (
    echo [错误] 未找到 OpenClaw CLI
    echo 请重新下载完整的一键包
    goto :error_exit
)

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"
if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"

set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%CONFIG_FILE%"
set "OPENCLAW_HOME=%CLAWSTART_HOME%"
set "PATH=%CLAWSTART_HOME%\runtime\node;%PATH%"

echo [1/3] 环境检查...
for /f "tokens=*" %%v in ('"%NODE_BIN%" --version 2^>nul') do set "NODE_VERSION=%%v"
if "!NODE_VERSION!"=="" (
    echo [错误] Node.js 运行时无法启动
    goto :error_exit
)
echo   OK Node.js !NODE_VERSION!

echo [2/3] 首次配置检查...
if not exist "%CONFIG_FILE%" (
    echo   检测到首次运行，将启动配置向导...
    call "%CLAWSTART_HOME%\first-run.bat"
    if !errorlevel! neq 0 (
        echo [错误] 首次配置未完成
        goto :error_exit
    )
)

echo [3/3] 启动 OpenClaw...
start /b "" "%NODE_BIN%" "%OPENCLAW_CLI%" gateway run --port %GATEWAY_PORT% --bind loopback --allow-unconfigured --force >"%LOGS_DIR%\gateway.log" 2>&1

set "WAIT_COUNT=0"
:wait_loop
timeout /t 1 /nobreak >nul 2>&1
set /a "WAIT_COUNT+=1"
powershell -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:%GATEWAY_PORT%' -TimeoutSec 2 -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if !errorlevel! equ 0 goto :service_ready
if !WAIT_COUNT! GEQ 30 (
    echo [错误] 启动超时，请查看 logs\gateway.log
    goto :error_exit
)
goto :wait_loop

:service_ready
echo.
echo OK OpenClaw 已启动
echo 正在打开浏览器: http://127.0.0.1:%GATEWAY_PORT%
start "" "http://127.0.0.1:%GATEWAY_PORT%"
echo.
echo 关闭此窗口将停止当前会话。
echo 遇到问题请运行 diagnose.bat
echo.

:keep_alive
timeout /t 3600 /nobreak >nul 2>&1
goto :keep_alive

:error_exit
echo.
echo 启动失败。请运行 diagnose.bat 获取诊断信息。
pause
exit /b 1
