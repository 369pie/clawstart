@echo off
setlocal

:: 确保工作目录为脚本所在目录
cd /d "%~dp0"
set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "NODE_BIN=%CLAWSTART_HOME%\runtime\node\node.exe"
set "OPENCLAW_CLI=%CLAWSTART_HOME%\runtime\npm-global\lib\node_modules\openclaw\openclaw.mjs"
set "STATE_DIR=%CLAWSTART_HOME%\state"
set "CONFIG_FILE=%STATE_DIR%\openclaw.json"
set "LOGS_DIR=%CLAWSTART_HOME%\logs"
set "GATEWAY_LOG=%LOGS_DIR%\gateway.log"
set "GATEWAY_PORT=18789"

if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%" >nul 2>&1

if not exist "%NODE_BIN%" (
    >>"%GATEWAY_LOG%" echo [gateway-runner] missing embedded Node.js: %NODE_BIN%
    exit /b 1
)

if not exist "%OPENCLAW_CLI%" (
    >>"%GATEWAY_LOG%" echo [gateway-runner] missing OpenClaw CLI: %OPENCLAW_CLI%
    exit /b 1
)

cd /d "%CLAWSTART_HOME%"
set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%CONFIG_FILE%"
set "OPENCLAW_HOME=%CLAWSTART_HOME%"
set "PATH=%CLAWSTART_HOME%\runtime\node;%PATH%"

:: Read gateway auth token from portable config and export as env var
:: so the gateway always uses the portable token, not ~/.openclaw fallback
if exist "%CONFIG_FILE%" (
    for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "try { $j = Get-Content -Raw -LiteralPath '%CONFIG_FILE%' | ConvertFrom-Json; if ($j.gateway.auth.token) { $j.gateway.auth.token } } catch { }" 2^>nul`) do (
        set "OPENCLAW_GATEWAY_TOKEN=%%t"
        >>"%GATEWAY_LOG%" echo [gateway-runner] loaded token from portable config
    )
)

>>"%GATEWAY_LOG%" echo [gateway-runner] starting OpenClaw gateway
"%NODE_BIN%" "%OPENCLAW_CLI%" gateway run --port %GATEWAY_PORT% --bind loopback --allow-unconfigured --force >>"%GATEWAY_LOG%" 2>&1
>>"%GATEWAY_LOG%" echo [gateway-runner] OpenClaw gateway exited with code %errorlevel%

exit /b %errorlevel%
