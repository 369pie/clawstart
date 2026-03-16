@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

title ClawStart Windows Beta

:: 确保工作目录为脚本所在目录，避免相对路径和子进程出错
cd /d "%~dp0"
set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "NODE_BIN=%CLAWSTART_HOME%\runtime\node\node.exe"
set "OPENCLAW_CLI=%CLAWSTART_HOME%\runtime\npm-global\lib\node_modules\openclaw\openclaw.mjs"
set "STATE_DIR=%CLAWSTART_HOME%\state"
set "CONFIG_FILE=%STATE_DIR%\openclaw.json"
set "WORKSPACE_DIR=%CLAWSTART_HOME%\workspace"
set "LOGS_DIR=%CLAWSTART_HOME%\logs"
set "GATEWAY_LOG=%LOGS_DIR%\gateway.log"
set "LAUNCHER_LOG=%LOGS_DIR%\launcher.log"
set "GATEWAY_PORT=18789"
set "WIZARD_PORT=18790"
set "GATEWAY_RUNNER=%CLAWSTART_HOME%\gateway-runner.bat"
set "CONFIG_WIZARD=%CLAWSTART_HOME%\config-wizard\config-server.mjs"

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

if not exist "%GATEWAY_RUNNER%" (
    echo [错误] 未找到 Gateway 启动器
    echo 请重新下载完整的一键包
    goto :error_exit
)

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"
if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if exist "%LAUNCHER_LOG%" del /q "%LAUNCHER_LOG%" >nul 2>&1
call :log launcher started from %CLAWSTART_HOME%

set "OPENCLAW_STATE_DIR=%STATE_DIR%"
set "OPENCLAW_CONFIG_PATH=%CONFIG_FILE%"
set "OPENCLAW_HOME=%CLAWSTART_HOME%"
set "PATH=%CLAWSTART_HOME%\runtime\node;%PATH%"

echo [1/4] 环境检查...
for /f "tokens=*" %%v in ('"%NODE_BIN%" --version 2^>nul') do set "NODE_VERSION=%%v"
if "!NODE_VERSION!"=="" (
    call :log embedded Node.js failed to report version
    echo [错误] Node.js 运行时无法启动
    goto :error_exit
)
call :log embedded Node.js version !NODE_VERSION!
echo   OK Node.js !NODE_VERSION!

echo [2/4] 启动配置服务...
:: 始终启动配置向导服务，用户可随时通过 http://127.0.0.1:18790 修改 Provider / API Key
if exist "%CONFIG_WIZARD%" (
    call :log starting config-server.mjs on port %WIZARD_PORT% (always-on)
    start "" /min cmd.exe /d /c ""%NODE_BIN%" "%CONFIG_WIZARD%" --port %WIZARD_PORT% --gateway-port %GATEWAY_PORT% >"%LOGS_DIR%\config-wizard.log" 2>&1"
    :: 等待配置服务就绪
    set "WIZ_WAIT=0"
    :wiz_wait_loop
    powershell -NoProfile -Command "Start-Sleep -Milliseconds 500" >nul 2>&1
    set /a "WIZ_WAIT+=1"
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:%WIZARD_PORT%/api/status' -TimeoutSec 2 -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 goto :wiz_ready
    if !WIZ_WAIT! GEQ 20 (
        call :log config wizard failed to start after !WIZ_WAIT! attempts
        echo   [警告] 配置向导启动失败，继续启动 Gateway...
        goto :check_config
    )
    goto :wiz_wait_loop
    :wiz_ready
    call :log config wizard ready on port %WIZARD_PORT%
    echo   OK 配置服务已启动 http://127.0.0.1:%WIZARD_PORT%
) else (
    call :log config-wizard not found, skipping
    echo   [警告] 未找到配置向导文件
)

:: 检测是否需要弹出向导界面
:check_config
set "NEED_WIZARD=1"
if exist "%CONFIG_FILE%" (
    powershell -NoProfile -Command "try { $j = Get-Content -Raw -LiteralPath '%CONFIG_FILE%' | ConvertFrom-Json; if ($j.gateway.skipWizard -eq $true) { exit 0 }; $e = $j.env; if ($e -and ($e.PSObject.Properties | Measure-Object).Count -gt 0) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
    if !errorlevel! equ 0 (
        set "NEED_WIZARD=0"
        call :log config has env section or skipWizard, provider configured
    ) else (
        call :log config missing env section, will open wizard
    )
) else (
    call :log config file not found, will open wizard
)

if "!NEED_WIZARD!"=="0" goto :config_done

:: 弹出向导让用户配置
if exist "%CONFIG_WIZARD%" (
    set "WIZARD_URL=http://127.0.0.1:%WIZARD_PORT%"
    echo.
    echo   检测到尚未配置 AI 服务商，正在打开配置向导...
    echo   !WIZARD_URL!
    start "" "!WIZARD_URL!"
    echo.
    echo   请在浏览器中完成配置，完成后此窗口将自动继续...
    echo.
    :: 等待配置完成（轮询 env+model 均就绪，或用户选择跳过）
    :wiz_config_wait
    powershell -NoProfile -Command "Start-Sleep -Seconds 2" >nul 2>&1
    if not exist "%CONFIG_FILE%" goto :wiz_config_wait
    powershell -NoProfile -Command "try { $j = Get-Content -Raw -LiteralPath '%CONFIG_FILE%' | ConvertFrom-Json; if ($j.gateway.skipWizard -eq $true) { exit 0 }; $e = $j.env; $m = $j.agents.defaults.model.primary; if ($e -and ($e.PSObject.Properties | Measure-Object).Count -gt 0 -and $m) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
    if !errorlevel! neq 0 goto :wiz_config_wait
    call :log config wizard completed, env section found
    echo   OK 配置完成!
) else (
    echo [错误] 未配置 AI 服务商，且配置向导不可用
    goto :error_exit
)

:config_done
call :log config ready at %CONFIG_FILE%

echo [3/4] 启动 OpenClaw...
if exist "%GATEWAY_LOG%" del /q "%GATEWAY_LOG%" >nul 2>&1
call :log launching gateway-runner.bat in background
start "" /min cmd.exe /d /c call "%GATEWAY_RUNNER%"

set "WAIT_COUNT=0"
:wait_loop
powershell -NoProfile -Command "Start-Sleep -Seconds 1" >nul 2>&1
set /a "WAIT_COUNT+=1"
call :log waiting for gateway health, attempt !WAIT_COUNT!
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri 'http://127.0.0.1:%GATEWAY_PORT%' -TimeoutSec 2 -UseBasicParsing | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
if !errorlevel! equ 0 (
    call :log gateway became healthy on port %GATEWAY_PORT%
    goto :service_ready
)
if !WAIT_COUNT! GEQ 30 (
    call :log gateway health check timed out after !WAIT_COUNT! attempts
    echo [错误] 启动超时，请查看 logs\gateway.log
    call :print_log_hint
    goto :error_exit
)
goto :wait_loop

:service_ready
echo.
echo [4/4] 打开工作台...
echo OK OpenClaw 已启动
set "DASHBOARD_URL=http://127.0.0.1:%GATEWAY_PORT%"
:: 从配置文件读取网关令牌，若有则打开带 token 的 URL，避免仪表盘 device_token_mismatch
set "GATEWAY_TOKEN="
if exist "%CONFIG_FILE%" (
    for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "try { $j = Get-Content -Raw -LiteralPath '%CONFIG_FILE%' | ConvertFrom-Json; if ($j.gateway.auth.token) { $j.gateway.auth.token } } catch { }" 2^>nul`) do set "GATEWAY_TOKEN=%%t"
)
if not "!GATEWAY_TOKEN!"=="" (
    set "DASHBOARD_URL=http://127.0.0.1:%GATEWAY_PORT%/#token=!GATEWAY_TOKEN!"
    call :log opening browser with token
) else (
    call :log opening browser without token (config may not have gateway.auth.token yet)
)
echo 正在打开浏览器: !DASHBOARD_URL!
start "" "!DASHBOARD_URL!"
echo.
echo 关闭此窗口将停止当前会话。
echo 随时访问 http://127.0.0.1:%WIZARD_PORT% 修改 AI 服务商配置
echo 遇到问题请运行 diagnose.bat
echo.

:keep_alive
powershell -NoProfile -Command "Start-Sleep -Seconds 3600" >nul 2>&1
goto :keep_alive

:print_log_hint
call :log printing recent gateway log tail
if exist "%GATEWAY_LOG%" (
    echo.
    echo ===== logs\gateway.log 最近内容 =====
    powershell -NoProfile -Command "if (Test-Path '%GATEWAY_LOG%') { Get-Content -Path '%GATEWAY_LOG%' -Tail 20 }" 2>nul
    if errorlevel 1 type "%GATEWAY_LOG%"
    echo ===== 结束 =====
)
goto :eof

:error_exit
call :log launcher entering error exit path
echo.
echo 启动失败。请运行 diagnose.bat 获取诊断信息。
echo 如需手动查看日志，请打开 logs\launcher.log 和 logs\gateway.log
pause
exit /b 1

:log
>>"%LAUNCHER_LOG%" echo [%date% %time%] %*
goto :eof
