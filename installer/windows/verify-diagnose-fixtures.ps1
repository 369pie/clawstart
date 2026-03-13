$ErrorActionPreference = "Stop"

function Assert-Contains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    if (-not (Select-String -Path $Path -Pattern $Pattern -SimpleMatch -Quiet)) {
        Write-Host "FAIL: $Message" -ForegroundColor Red
        Write-Host "  file: $Path"
        Write-Host "  expected: $Pattern"
        exit 1
    }
}

function New-FakeNode {
    param([string]$Destination)

    New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
    Copy-Item "$PSHOME\powershell.exe" $Destination -Force
}

function Invoke-DiagnoseCase {
    param(
        [string]$Name,
        [string]$ExpectedError,
        [string]$ExpectedRule,
        [string]$ExpectedTitle,
        [bool]$IncludeNode = $true,
        [bool]$IncludeProvider = $true,
        [string]$LogBody = ""
    )

    $caseDir = Join-Path $script:TempRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    Copy-Item $script:BatchSource (Join-Path $caseDir "diagnose.bat") -Force

    if ($IncludeNode) {
        New-FakeNode (Join-Path $caseDir "runtime\node\node.exe")
    }

    if ($IncludeProvider) {
        New-Item -ItemType Directory -Force -Path (Join-Path $caseDir "state") | Out-Null
        Set-Content -Path (Join-Path $caseDir "state\openclaw.json") -Encoding UTF8 -Value '{"gateway":{"mode":"local"},"agents":{"defaults":{"workspace":"./workspace"}}}'
    }

    if ($LogBody) {
        New-Item -ItemType Directory -Force -Path (Join-Path $caseDir "logs") | Out-Null
        Set-Content -Path (Join-Path $caseDir "logs\gateway.log") -Encoding UTF8 -Value $LogBody
    }

    Write-Host ""
    Write-Host "[Windows $Name]" -ForegroundColor Cyan

    Push-Location $caseDir
    try {
        cmd.exe /c "set CLAWSTART_NO_PAUSE=1&& call `"$caseDir\diagnose.bat`"" | Out-Null
    } finally {
        Pop-Location
    }

    $report = Join-Path $caseDir "diagnostic.txt"
    Assert-Contains $report "error_code: $ExpectedError" "Windows $Name 应命中 $ExpectedError"
    Assert-Contains $report "matched_rule: $ExpectedRule" "Windows $Name 应命中规则 $ExpectedRule"
    Assert-Contains $report "human_title: $ExpectedTitle" "Windows $Name 应输出标题 $ExpectedTitle"
    Assert-Contains $report "recommended_action:" "Windows $Name 应输出建议动作"
    Assert-Contains $report "--- 规则化诊断结论 ---" "Windows $Name 应写入规则化结论区块"

    Write-Host "PASS: $Name" -ForegroundColor Green
    $script:PassCount += 1
}

$script:BatchSource = Join-Path $PSScriptRoot "diagnose.bat"
$script:TempRoot = Join-Path $env:TEMP ("clawstart-diagnose-fixtures-" + [guid]::NewGuid().ToString("N"))
$script:PassCount = 0
New-Item -ItemType Directory -Force -Path $script:TempRoot | Out-Null

try {
    Invoke-DiagnoseCase -Name "missing-node" -ExpectedError "NODE_EMBEDDED_MISSING" -ExpectedRule "ENV_NODE_MISSING" -ExpectedTitle "未找到内嵌 Node.js 运行时" -IncludeNode:$false -IncludeProvider:$false
    Invoke-DiagnoseCase -Name "missing-provider" -ExpectedError "CONFIG_OPENCLAW_MISSING" -ExpectedRule "CFG_OPENCLAW_SETUP_MISSING" -ExpectedTitle "还没有完成 OpenClaw 首次配置" -IncludeNode:$true -IncludeProvider:$false
    Invoke-DiagnoseCase -Name "git-ssh" -ExpectedError "GIT_SSH_PERMISSION" -ExpectedRule "R001" -ExpectedTitle "Git SSH 权限错误" -LogBody "Error: permission denied (publickey)`r`nfatal: Could not read from remote repository ssh://git@github.com/example/repo.git"

    Write-Host ""
    Write-Host "Summary: $script:PassCount passed" -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
