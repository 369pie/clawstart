@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================
:: ClawStart 诊断工具
:: 收集系统信息，帮助排查问题
:: ============================================================

set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "CYAN=[96m"
set "RESET=[0m"
set "BOLD=[1m"

set "CLAWSTART_HOME=%~dp0"
set "CLAWSTART_HOME=%CLAWSTART_HOME:~0,-1%"
set "REPORT=%CLAWSTART_HOME%\diagnostic.txt"
set "PRIMARY_LOG=%CLAWSTART_HOME%\logs\gateway.log"
set "SECONDARY_LOG=%USERPROFILE%\.openclaw\logs\gateway.log"
set "STATE_DIR=%CLAWSTART_HOME%\state"
set "CONFIG_FILE=%STATE_DIR%\openclaw.json"

set "ERROR_CODE=OK"
set "MATCHED_RULE=NONE"
set "HUMAN_TITLE=未发现明确错误规则"
set "RECOMMENDED_ACTION=优先回到快速开始逐步检查；如仍失败，再把本报告发给支持人员。"
set "MANUAL_COMMAND="

echo.
echo %CYAN%  ClawStart 诊断工具%RESET%
echo   正在收集系统信息...
echo.

:: 清空报告
echo ============================== > "%REPORT%"
echo  ClawStart 诊断报告 >> "%REPORT%"
echo  生成时间: %date% %time% >> "%REPORT%"
echo ============================== >> "%REPORT%"
echo. >> "%REPORT%"

call :detect_rule

:: 系统信息
echo   [1/6] 系统信息...
echo --- 系统信息 --- >> "%REPORT%"
systeminfo | findstr /C:"OS" /C:"系统" /C:"处理器" /C:"内存" >> "%REPORT%" 2>nul
echo. >> "%REPORT%"

:: 磁盘空间
echo   [2/6] 磁盘空间...
echo --- 磁盘空间 --- >> "%REPORT%"
wmic logicaldisk get caption,freespace,size /format:list >> "%REPORT%" 2>nul
echo. >> "%REPORT%"

:: Node.js 检测
echo   [3/6] Node.js 环境...
echo --- Node.js --- >> "%REPORT%"
if exist "%CLAWSTART_HOME%\runtime\node\node.exe" (
    "%CLAWSTART_HOME%\runtime\node\node.exe" --version >> "%REPORT%" 2>&1
    echo 内嵌 Node.js: 存在 >> "%REPORT%"
) else (
    echo 内嵌 Node.js: 未找到 >> "%REPORT%"
)
where node >> "%REPORT%" 2>nul
if !errorlevel! neq 0 echo 系统 Node.js: 未安装 >> "%REPORT%"
echo. >> "%REPORT%"

:: 端口检测
echo   [4/6] 端口占用...
echo --- 端口检测 --- >> "%REPORT%"
netstat -ano | findstr ":3000 :3001 :8080 :8888" >> "%REPORT%" 2>nul
if !errorlevel! neq 0 echo 常用端口(3000/3001/8080/8888): 均空闲 >> "%REPORT%"
echo. >> "%REPORT%"

:: 配置检测
echo   [5/6] 配置文件...
echo --- 配置文件 --- >> "%REPORT%"
if exist "%CONFIG_FILE%" (
    echo openclaw.json: 存在 >> "%REPORT%"
    type "%CONFIG_FILE%" | findstr "workspace gateway agents" >> "%REPORT%"
) else (
    echo openclaw.json: 未配置 >> "%REPORT%"
)
echo. >> "%REPORT%"

:: 网络连通性
echo   [6/6] 网络连通性...
echo --- 网络测试 --- >> "%REPORT%"
ping -n 1 -w 3000 baidu.com >nul 2>&1
if !errorlevel! equ 0 (
    echo 基础网络: 正常 >> "%REPORT%"
) else (
    echo 基础网络: 异常 >> "%REPORT%"
)
ping -n 1 -w 3000 api.deepseek.com >nul 2>&1
if !errorlevel! equ 0 (
    echo DeepSeek API: 可达 >> "%REPORT%"
) else (
    echo DeepSeek API: 不可达 >> "%REPORT%"
)
echo. >> "%REPORT%"

echo --- 规则化诊断结论 --- >> "%REPORT%"
echo error_code: %ERROR_CODE% >> "%REPORT%"
echo matched_rule: %MATCHED_RULE% >> "%REPORT%"
echo human_title: %HUMAN_TITLE% >> "%REPORT%"
echo recommended_action: %RECOMMENDED_ACTION% >> "%REPORT%"
if not "%MANUAL_COMMAND%"=="" echo manual_command: %MANUAL_COMMAND% >> "%REPORT%"
echo. >> "%REPORT%"

echo --- 日志来源 --- >> "%REPORT%"
if exist "%PRIMARY_LOG%" (
    echo primary_log: %PRIMARY_LOG% >> "%REPORT%"
) else (
    echo primary_log: NOT_FOUND >> "%REPORT%"
)
if exist "%SECONDARY_LOG%" (
    echo secondary_log: %SECONDARY_LOG% >> "%REPORT%"
) else (
    echo secondary_log: NOT_FOUND >> "%REPORT%"
)
echo. >> "%REPORT%"

echo ============================== >> "%REPORT%"
echo  诊断完成 >> "%REPORT%"
echo ============================== >> "%REPORT%"

echo.
echo %GREEN%  ✓ 诊断完成！%RESET%
echo.
echo   规则化结论: %CYAN%%HUMAN_TITLE%%RESET%
echo   建议动作: %YELLOW%%RECOMMENDED_ACTION%%RESET%
if not "%MANUAL_COMMAND%"=="" echo   手动命令: %CYAN%%MANUAL_COMMAND%%RESET%
echo.
echo   报告已保存到: %CYAN%%REPORT%%RESET%
echo.
echo   %YELLOW%如需帮助，请将 diagnostic.txt 发到社群：%RESET%
echo     QQ群: [待填写]
echo     微信群: [待填写]
echo.
if /I "%CLAWSTART_NO_PAUSE%"=="1" goto :eof
if /I "%CI%"=="true" goto :eof
pause

goto :eof

:detect_rule
if not exist "%CLAWSTART_HOME%\runtime\node\node.exe" (
    set "ERROR_CODE=NODE_EMBEDDED_MISSING"
    set "MATCHED_RULE=ENV_NODE_MISSING"
    set "HUMAN_TITLE=未找到内嵌 Node.js 运行时"
    set "RECOMMENDED_ACTION=重新下载完整的一键包，不要只复制单个脚本。"
    goto :eof
)

if not exist "%CONFIG_FILE%" (
    set "ERROR_CODE=CONFIG_OPENCLAW_MISSING"
    set "MATCHED_RULE=CFG_OPENCLAW_SETUP_MISSING"
    set "HUMAN_TITLE=还没有完成 OpenClaw 首次配置"
    set "RECOMMENDED_ACTION=重新运行 launch.bat 或 first-run.bat，完成首次配置。"
    goto :eof
)

if exist "%PRIMARY_LOG%" call :detect_rule_from_file "%PRIMARY_LOG%"
if "%MATCHED_RULE%"=="NONE" if exist "%SECONDARY_LOG%" call :detect_rule_from_file "%SECONDARY_LOG%"
goto :eof

:detect_rule_from_file
set "LOG_FILE=%~1"

findstr /I /C:"permission denied (publickey)" /C:"ssh://git@github" /C:"git@github.com" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=GIT_SSH_PERMISSION"
    set "MATCHED_RULE=R001"
    set "HUMAN_TITLE=Git SSH 权限错误"
    set "RECOMMENDED_ACTION=把 Git 拉取方式切到 HTTPS，再重新安装。"
    set "MANUAL_COMMAND=git config --global url.https://github.com/.insteadOf ssh://git@github.com/"
    goto :eof
)

findstr /I /C:"exit 128" /C:"code 128" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=GIT_EXIT_128"
    set "MATCHED_RULE=R002"
    set "HUMAN_TITLE=Git 操作异常"
    set "RECOMMENDED_ACTION=先确认 Git 可用，再切换到 HTTPS 模式。"
    set "MANUAL_COMMAND=git --version"
    goto :eof
)

findstr /I /C:"cannot find native binding" /C:"native binding" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=NATIVE_BINDING_MISSING"
    set "MATCHED_RULE=R003"
    set "HUMAN_TITLE=原生依赖缺失"
    set "RECOMMENDED_ACTION=重新安装底层 OpenClaw CLI。"
    set "MANUAL_COMMAND=npm i -g openclaw"
    goto :eof
)

findstr /I /C:"eperm" /C:"operation not permitted" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=FILE_PERMISSION_BLOCKED"
    set "MATCHED_RULE=R004"
    set "HUMAN_TITLE=文件被占用或权限不足"
    set "RECOMMENDED_ACTION=关闭旧进程、暂时关闭杀软拦截，并用管理员权限重试。"
    goto :eof
)

findstr /I /C:"enoent" /C:"-4058" /C:"cannot find module" /C:"module_not_found" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=INSTALL_INCOMPLETE"
    set "MATCHED_RULE=R005_R007"
    set "HUMAN_TITLE=文件缺失或安装不完整"
    set "RECOMMENDED_ACTION=清理缓存后重装；一键包用户优先重新下载并解压到新目录。"
    set "MANUAL_COMMAND=npm cache clean --force"
    goto :eof
)

findstr /I /C:"eacces" /C:"permission denied" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=ACCESS_DENIED"
    set "MATCHED_RULE=R006"
    set "HUMAN_TITLE=安装权限不足"
    set "RECOMMENDED_ACTION=请以管理员身份打开 PowerShell 或终端后重试。"
    goto :eof
)

findstr /I /C:"etimedout" /C:"econnrefused" /C:"enotfound" /C:"fetch failed" /C:"socket hang up" /C:"econnreset" /C:"unable to get local issuer" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=NETWORK_UNREACHABLE"
    set "MATCHED_RULE=R008"
    set "HUMAN_TITLE=网络、代理或证书问题"
    set "RECOMMENDED_ACTION=先切换网络或关闭代理，再优先使用国内镜像重试。"
    set "MANUAL_COMMAND=npm config set strict-ssl false"
    goto :eof
)

findstr /I /C:"integrity" /C:"sha512" /C:"cache" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=NPM_CACHE_CORRUPTED"
    set "MATCHED_RULE=R009"
    set "HUMAN_TITLE=npm 缓存异常"
    set "RECOMMENDED_ACTION=清理 npm 缓存后重新安装。"
    set "MANUAL_COMMAND=npm cache clean --force"
    goto :eof
)

findstr /I /C:"engine" /C:"unsupported" /C:"required:" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=NODE_VERSION_UNSUPPORTED"
    set "MATCHED_RULE=R010"
    set "HUMAN_TITLE=Node.js 版本不兼容"
    set "RECOMMENDED_ACTION=先升级 Node.js 到当前要求版本以上，再重新执行安装。"
    goto :eof
)

findstr /I /C:"cb() never called" /C:"npm err" /C:"code 1" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=NPM_RUNTIME_ERROR"
    set "MATCHED_RULE=R011"
    set "HUMAN_TITLE=npm 本身异常"
    set "RECOMMENDED_ACTION=先升级 npm，再重新安装底层 CLI。"
    set "MANUAL_COMMAND=npm install -g npm@latest"
    goto :eof
)

findstr /I /C:"enospc" /C:"no space" "%LOG_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "ERROR_CODE=DISK_SPACE_LOW"
    set "MATCHED_RULE=R012"
    set "HUMAN_TITLE=磁盘空间不足"
    set "RECOMMENDED_ACTION=先清理磁盘空间，再重新安装或启动。"
    goto :eof
)

goto :eof
