@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================
:: ClawStart 一键启动器 (Windows)
:: 双击即可启动 OpenClaw，无需任何安装
:: ============================================================

title ClawStart - OpenClaw 中文免安装版

:: 颜色代码
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "CYAN=[96m"
set "RESET=[0m"
set "BOLD=[1m"

:: 路径设置
set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "NODE_DIR=%CLAWSTART_HOME%\runtime\node"
set "OPENCLAW_DIR=%CLAWSTART_HOME%\openclaw"
set "CONFIG_DIR=%CLAWSTART_HOME%\config"
set "WORKSPACE_DIR=%CLAWSTART_HOME%\workspace"
set "GATEWAY_PORT=3000"

:: Banner
echo.
echo %CYAN%  ╔══════════════════════════════════════╗%RESET%
echo %CYAN%  ║                                      ║%RESET%
echo %CYAN%  ║   🐾  ClawStart - OpenClaw 一键启动  ║%RESET%
echo %CYAN%  ║                                      ║%RESET%
echo %CYAN%  ╚══════════════════════════════════════╝%RESET%
echo.

:: ============================================================
:: 环境自检
:: ============================================================
echo %BOLD%[1/4] 环境检查...%RESET%

:: 检查 Node.js 运行时
if not exist "%NODE_DIR%\node.exe" (
    echo %RED%[错误] 未找到内嵌 Node.js 运行时%RESET%
    echo        预期路径: %NODE_DIR%\node.exe
    echo        请重新下载完整的 ClawStart 一键包
    goto :error_exit
)

:: 设置 PATH（内嵌 Node.js 优先）
set "PATH=%NODE_DIR%;%NODE_DIR%\node_modules\.bin;%PATH%"

:: 验证 Node.js 可用
for /f "tokens=*" %%v in ('"%NODE_DIR%\node.exe" --version 2^>nul') do set "NODE_VERSION=%%v"
if "!NODE_VERSION!"=="" (
    echo %RED%[错误] Node.js 运行时无法启动%RESET%
    echo        请运行 diagnose.bat 获取详细诊断信息
    goto :error_exit
)
echo   %GREEN%✓%RESET% Node.js 运行时: !NODE_VERSION!

:: 检查 OpenClaw 本体
if not exist "%OPENCLAW_DIR%\package.json" (
    echo %RED%[错误] 未找到 OpenClaw 本体%RESET%
    echo        预期路径: %OPENCLAW_DIR%
    echo        请重新下载完整的 ClawStart 一键包
    goto :error_exit
)
echo   %GREEN%✓%RESET% OpenClaw 本体已就绪

:: 检查磁盘空间（需要至少 500MB 可用）
for /f "tokens=3" %%a in ('dir "%CLAWSTART_HOME%" /-c 2^>nul ^| findstr /c:"bytes free"') do (
    set "FREE_BYTES=%%a"
)
:: 简单检查：如果可用空间字符串长度小于10位（约1GB以下），发出警告
set "SPACE_LEN=0"
for /l %%i in (0,1,12) do (
    if not "!FREE_BYTES:~%%i,1!"=="" set "SPACE_LEN=%%i"
)
if !SPACE_LEN! LSS 9 (
    echo   %YELLOW%⚠ 磁盘空间不足，建议保留至少 500MB 可用空间%RESET%
) else (
    echo   %GREEN%✓%RESET% 磁盘空间充足
)

:: 检查端口占用
netstat -ano 2>nul | findstr /c:":%GATEWAY_PORT% " | findstr /c:"LISTENING" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %YELLOW%⚠ 端口 %GATEWAY_PORT% 已被占用%RESET%
    echo     正在尝试查找可用端口...
    set /a "GATEWAY_PORT+=1"
    :find_port
    netstat -ano 2>nul | findstr /c:":%GATEWAY_PORT% " | findstr /c:"LISTENING" >nul 2>&1
    if !errorlevel! equ 0 (
        set /a "GATEWAY_PORT+=1"
        if !GATEWAY_PORT! GTR 3010 (
            echo %RED%[错误] 端口 3000-3010 均被占用，请关闭占用程序后重试%RESET%
            goto :error_exit
        )
        goto :find_port
    )
    echo   %GREEN%✓%RESET% 使用备用端口: !GATEWAY_PORT!
) else (
    echo   %GREEN%✓%RESET% 端口 %GATEWAY_PORT% 可用
)

echo.

:: ============================================================
:: 首次运行检测
:: ============================================================
echo %BOLD%[2/4] 配置检查...%RESET%

if not exist "%CONFIG_DIR%\provider.json" (
    echo   %YELLOW%检测到首次运行，即将启动配置向导...%RESET%
    echo.
    if exist "%CLAWSTART_HOME%\first-run.bat" (
        call "%CLAWSTART_HOME%\first-run.bat"
        if !errorlevel! neq 0 (
            echo %RED%[错误] 首次运行配置未完成%RESET%
            echo        你可以稍后重新运行 first-run.bat 完成配置
            goto :error_exit
        )
    ) else (
        echo %RED%[错误] 未找到首次运行引导脚本%RESET%
        goto :error_exit
    )
)

if exist "%CONFIG_DIR%\provider.json" (
    echo   %GREEN%✓%RESET% 模型配置已就绪
) else (
    echo   %YELLOW%⚠ 未找到模型配置，服务可能无法正常使用%RESET%
)

echo.

:: ============================================================
:: 启动服务
:: ============================================================
echo %BOLD%[3/4] 启动 OpenClaw 服务...%RESET%
echo   端口: !GATEWAY_PORT!
echo.

:: 设置环境变量
set "OPENCLAW_PORT=!GATEWAY_PORT!"
set "OPENCLAW_CONFIG=%CONFIG_DIR%"
set "OPENCLAW_WORKSPACE=%WORKSPACE_DIR%"

:: 启动 gateway（后台运行）
start /b "" "%NODE_DIR%\node.exe" "%OPENCLAW_DIR%\server.js" --port !GATEWAY_PORT! >"%CLAWSTART_HOME%\logs\gateway.log" 2>&1

:: 等待服务就绪（最多等待 30 秒）
echo   等待服务启动...
set "WAIT_COUNT=0"
:wait_loop
timeout /t 1 /nobreak >nul 2>&1
set /a "WAIT_COUNT+=1"

:: 尝试连接服务
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:!GATEWAY_PORT!/health' -TimeoutSec 2 -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1
if !errorlevel! equ 0 goto :service_ready

if !WAIT_COUNT! GEQ 30 (
    echo.
    echo %RED%[错误] 服务启动超时（30秒）%RESET%
    echo        请查看日志: %CLAWSTART_HOME%\logs\gateway.log
    echo        或运行 diagnose.bat 获取诊断信息
    goto :error_exit
)

:: 进度动画
set /a "DOT_COUNT=WAIT_COUNT %% 4"
if !DOT_COUNT! equ 0 set "DOTS=."
if !DOT_COUNT! equ 1 set "DOTS=.."
if !DOT_COUNT! equ 2 set "DOTS=..."
if !DOT_COUNT! equ 3 set "DOTS=...."
<nop>set /p "=  启动中!DOTS!   " <nul
echo.
goto :wait_loop

:service_ready
echo.
echo   %GREEN%✓ 服务已启动！%RESET%
echo.

:: ============================================================
:: 打开浏览器
:: ============================================================
echo %BOLD%[4/4] 打开浏览器...%RESET%

set "URL=http://localhost:!GATEWAY_PORT!"
start "" "%URL%"
echo   %GREEN%✓%RESET% 已在浏览器中打开: %CYAN%!URL!%RESET%

echo.
echo %GREEN%══════════════════════════════════════════%RESET%
echo %GREEN%  ClawStart 已就绪！%RESET%
echo %GREEN%  访问地址: %CYAN%!URL!%RESET%
echo %GREEN%══════════════════════════════════════════%RESET%
echo.
echo %YELLOW%提示：%RESET%
echo   - 关闭此窗口将停止服务
echo   - 遇到问题请运行 diagnose.bat
echo   - 社群求助: https://clawstart.openclaw.cn/community
echo.
echo 按 Ctrl+C 或关闭窗口停止服务...
echo.

:: 保持窗口打开，等待用户关闭
:keep_alive
timeout /t 3600 /nobreak >nul 2>&1
goto :keep_alive

:: ============================================================
:: 错误退出
:: ============================================================
:error_exit
echo.
echo %RED%启动失败。%RESET%请尝试以下操作：
echo   1. 运行 diagnose.bat 获取诊断信息
echo   2. 将 diagnostic.txt 发送到社群求助
echo   3. 访问 https://clawstart.openclaw.cn/troubleshooting
echo.
pause
exit /b 1
