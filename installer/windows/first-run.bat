@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================
:: ClawStart 首次运行引导
:: 引导用户选择模型提供商并配置 API Key
:: ============================================================

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
set "CONFIG_DIR=%CLAWSTART_HOME%\config"
set "NODE_DIR=%CLAWSTART_HOME%\runtime\node"

:: 确保配置目录存在
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"

:: ============================================================
:: 欢迎信息
:: ============================================================
cls
echo.
echo %CYAN%  ╔══════════════════════════════════════════════╗%RESET%
echo %CYAN%  ║                                              ║%RESET%
echo %CYAN%  ║   🐾  欢迎使用 ClawStart！                  ║%RESET%
echo %CYAN%  ║                                              ║%RESET%
echo %CYAN%  ║   OpenClaw 中文免安装版                      ║%RESET%
echo %CYAN%  ║   首次运行需要简单配置，只需 1 分钟          ║%RESET%
echo %CYAN%  ║                                              ║%RESET%
echo %CYAN%  ╚══════════════════════════════════════════════╝%RESET%
echo.
echo   接下来将引导你完成以下配置：
echo     1. 选择 AI 模型提供商
echo     2. 输入 API Key
echo     3. 测试连通性
echo.
pause

:: ============================================================
:: 模型选择菜单
:: ============================================================
:select_provider
cls
echo.
echo %BOLD%  ═══ 选择 AI 模型提供商 ═══%RESET%
echo.
echo   %CYAN%[1]%RESET% 火山引擎（豆包）
echo       推荐，国内速度快，注册送额度
echo       模型: doubao-pro-256k
echo.
echo   %CYAN%[2]%RESET% 硅基流动（SiliconFlow）
echo       性价比高，支持多种开源模型
echo       模型: deepseek-ai/DeepSeek-V3
echo.
echo   %CYAN%[3]%RESET% DeepSeek 官方
echo       直连 DeepSeek，模型能力强
echo       模型: deepseek-chat
echo.
echo   %CYAN%[4]%RESET% 自定义（OpenAI 兼容接口）
echo       适合使用其他服务商或自建服务
echo.
echo   %CYAN%[0]%RESET% 跳过配置（稍后手动配置）
echo.
set /p "CHOICE=  请输入选项 [1-4, 0跳过]: "

if "!CHOICE!"=="0" goto :skip_config
if "!CHOICE!"=="1" goto :provider_volcengine
if "!CHOICE!"=="2" goto :provider_siliconflow
if "!CHOICE!"=="3" goto :provider_deepseek
if "!CHOICE!"=="4" goto :provider_custom

echo   %RED%无效选项，请重新选择%RESET%
timeout /t 1 /nobreak >nul
goto :select_provider

:: ============================================================
:: 火山引擎配置
:: ============================================================
:provider_volcengine
set "PROVIDER_NAME=volcengine"
set "PROVIDER_DISPLAY=火山引擎（豆包）"
set "API_BASE=https://ark.cn-beijing.volces.com/api/v3"
set "MODEL_ID=doubao-pro-256k"
echo.
echo %BOLD%  ═══ 火山引擎配置 ═══%RESET%
echo.
echo   %YELLOW%获取 API Key 步骤：%RESET%
echo     1. 访问 https://console.volcengine.com/ark
echo     2. 注册/登录火山引擎账号
echo     3. 进入「模型推理」→「API Key 管理」
echo     4. 创建 API Key 并复制
echo.
goto :input_apikey

:: ============================================================
:: 硅基流动配置
:: ============================================================
:provider_siliconflow
set "PROVIDER_NAME=siliconflow"
set "PROVIDER_DISPLAY=硅基流动（SiliconFlow）"
set "API_BASE=https://api.siliconflow.cn/v1"
set "MODEL_ID=deepseek-ai/DeepSeek-V3"
echo.
echo %BOLD%  ═══ 硅基流动配置 ═══%RESET%
echo.
echo   %YELLOW%获取 API Key 步骤：%RESET%
echo     1. 访问 https://cloud.siliconflow.cn
echo     2. 注册/登录账号
echo     3. 进入「API 密钥」页面
echo     4. 创建密钥并复制
echo.
goto :input_apikey

:: ============================================================
:: DeepSeek 配置
:: ============================================================
:provider_deepseek
set "PROVIDER_NAME=deepseek"
set "PROVIDER_DISPLAY=DeepSeek 官方"
set "API_BASE=https://api.deepseek.com/v1"
set "MODEL_ID=deepseek-chat"
echo.
echo %BOLD%  ═══ DeepSeek 配置 ═══%RESET%
echo.
echo   %YELLOW%获取 API Key 步骤：%RESET%
echo     1. 访问 https://platform.deepseek.com
echo     2. 注册/登录账号
echo     3. 进入「API Keys」页面
echo     4. 创建 API Key 并复制
echo.
goto :input_apikey

:: ============================================================
:: 自定义配置
:: ============================================================
:provider_custom
set "PROVIDER_NAME=custom"
set "PROVIDER_DISPLAY=自定义"
echo.
echo %BOLD%  ═══ 自定义模型配置 ═══%RESET%
echo.
echo   请输入 OpenAI 兼容接口信息：
echo.
set /p "API_BASE=  API 地址 (如 https://api.example.com/v1): "
if "!API_BASE!"=="" (
    echo   %RED%API 地址不能为空%RESET%
    goto :provider_custom
)
set /p "MODEL_ID=  模型名称 (如 gpt-4): "
if "!MODEL_ID!"=="" (
    echo   %RED%模型名称不能为空%RESET%
    goto :provider_custom
)
goto :input_apikey

:: ============================================================
:: 输入 API Key
:: ============================================================
:input_apikey
echo.
set /p "API_KEY=  请粘贴你的 API Key: "

if "!API_KEY!"=="" (
    echo   %RED%API Key 不能为空，请重新输入%RESET%
    goto :input_apikey
)

:: 基本格式校验（长度检查）
set "KEY_LEN=0"
set "TEMP_KEY=!API_KEY!"
:count_len
if not "!TEMP_KEY!"=="" (
    set "TEMP_KEY=!TEMP_KEY:~1!"
    set /a "KEY_LEN+=1"
    goto :count_len
)
if !KEY_LEN! LSS 10 (
    echo   %RED%API Key 格式异常（太短），请检查后重新输入%RESET%
    goto :input_apikey
)

echo.
echo   已选择: %CYAN%!PROVIDER_DISPLAY!%RESET%
echo   模型:   %CYAN%!MODEL_ID!%RESET%
echo   API Key: %CYAN%!API_KEY:~0,8!****%RESET%
echo.

:: ============================================================
:: 测试 API 连通性
:: ============================================================
echo %BOLD%  测试 API 连通性...%RESET%
echo.

:: 使用 PowerShell 发送测试请求
set "TEST_BODY={\"model\":\"!MODEL_ID!\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":10}"

powershell -Command ^
    "$headers = @{ 'Authorization' = 'Bearer !API_KEY!'; 'Content-Type' = 'application/json' }; " ^
    "try { " ^
    "  $body = '!TEST_BODY!'; " ^
    "  $response = Invoke-WebRequest -Uri '!API_BASE!/chat/completions' -Method POST -Headers $headers -Body $body -TimeoutSec 15 -UseBasicParsing; " ^
    "  if ($response.StatusCode -eq 200) { exit 0 } else { Write-Host $response.StatusCode; exit 1 } " ^
    "} catch { " ^
    "  Write-Host $_.Exception.Message; " ^
    "  exit 1 " ^
    "}" >"%CLAWSTART_HOME%\logs\api-test.log" 2>&1

if !errorlevel! equ 0 (
    echo   %GREEN%✓ API 连通性测试通过！%RESET%
    goto :save_config
) else (
    echo   %RED%✗ API 连通性测试失败%RESET%
    echo.
    if exist "%CLAWSTART_HOME%\logs\api-test.log" (
        echo   错误信息：
        type "%CLAWSTART_HOME%\logs\api-test.log"
    )
    echo.
    echo   %YELLOW%可能的原因：%RESET%
    echo     - API Key 不正确
    echo     - 网络连接问题
    echo     - 服务商暂时不可用
    echo.
    echo   %CYAN%[1]%RESET% 重新输入 API Key
    echo   %CYAN%[2]%RESET% 重新选择提供商
    echo   %CYAN%[3]%RESET% 跳过测试，直接保存配置
    echo   %CYAN%[0]%RESET% 退出配置
    echo.
    set /p "RETRY=  请选择 [0-3]: "
    if "!RETRY!"=="1" goto :input_apikey
    if "!RETRY!"=="2" goto :select_provider
    if "!RETRY!"=="3" goto :save_config
    if "!RETRY!"=="0" exit /b 1
    goto :input_apikey
)

:: ============================================================
:: 保存配置
:: ============================================================
:save_config
echo.
echo %BOLD%  保存配置...%RESET%

:: 确保日志目录存在
if not exist "%CLAWSTART_HOME%\logs" mkdir "%CLAWSTART_HOME%\logs"

:: 写入 provider.json
(
echo {
echo   "provider": "!PROVIDER_NAME!",
echo   "displayName": "!PROVIDER_DISPLAY!",
echo   "apiBase": "!API_BASE!",
echo   "modelId": "!MODEL_ID!",
echo   "apiKey": "!API_KEY!"
echo }
) > "%CONFIG_DIR%\provider.json"

if !errorlevel! neq 0 (
    echo   %RED%✗ 配置保存失败%RESET%
    exit /b 1
)

echo   %GREEN%✓ 配置已保存到 config\provider.json%RESET%
echo.

:: ============================================================
:: 完成
:: ============================================================
echo %GREEN%  ╔══════════════════════════════════════════════╗%RESET%
echo %GREEN%  ║                                              ║%RESET%
echo %GREEN%  ║   ✅  配置完成！                             ║%RESET%
echo %GREEN%  ║                                              ║%RESET%
echo %GREEN%  ║   模型提供商: %-28s  ║%RESET%
echo %GREEN%  ║   即将启动 OpenClaw 服务...                  ║%RESET%
echo %GREEN%  ║                                              ║%RESET%
echo %GREEN%  ╚══════════════════════════════════════════════╝%RESET%
echo.
timeout /t 2 /nobreak >nul
exit /b 0

:: ============================================================
:: 跳过配置
:: ============================================================
:skip_config
echo.
echo   %YELLOW%已跳过首次配置。%RESET%
echo   你可以随时重新运行 first-run.bat 完成配置。
echo.

:: 创建空标记文件，避免每次启动都弹出引导
echo {} > "%CONFIG_DIR%\provider.json"
timeout /t 2 /nobreak >nul
exit /b 0
