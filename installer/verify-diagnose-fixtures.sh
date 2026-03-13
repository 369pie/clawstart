#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAC_SCRIPT="$ROOT_DIR/installer/macos/diagnose.sh"
WIN_SCRIPT="$ROOT_DIR/installer/windows/diagnose.bat"
TMP_BASE="$(mktemp -d /tmp/clawstart-diagnose-fixtures.XXXXXX)"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

pass_count=0
skip_count=0

print_header() {
    printf '\n[%s]\n' "$1"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    if ! rg -q --fixed-strings -- "$pattern" "$file"; then
        echo "FAIL: $message"
        echo "  file: $file"
        echo "  expected: $pattern"
        exit 1
    fi
}

run_mac_case() {
    local case_name="$1"
    local expected_error="$2"
    local expected_rule="$3"
    local expected_title="$4"
    local log_body="${5:-}"
    local include_node="${6:-yes}"
    local include_provider="${7:-yes}"

    local case_dir="$TMP_BASE/$case_name"
    mkdir -p "$case_dir"
    cp "$MAC_SCRIPT" "$case_dir/diagnose.sh"
    chmod +x "$case_dir/diagnose.sh"

    if [ "$include_node" = "yes" ]; then
        mkdir -p "$case_dir/runtime/node/bin"
        cat > "$case_dir/runtime/node/bin/node" <<'EOF'
#!/bin/bash
echo v20.11.0
EOF
        chmod +x "$case_dir/runtime/node/bin/node"
    fi

    if [ "$include_provider" = "yes" ]; then
        mkdir -p "$case_dir/config"
        cat > "$case_dir/config/provider.json" <<'EOF'
{"provider":"deepseek","modelId":"deepseek-chat","apiBase":"https://api.deepseek.com"}
EOF
    fi

    if [ -n "$log_body" ]; then
        mkdir -p "$case_dir/logs"
        printf '%s\n' "$log_body" > "$case_dir/logs/gateway.log"
    fi

    print_header "macOS $case_name"
    "$case_dir/diagnose.sh" >/dev/null

    assert_contains "$case_dir/diagnostic.txt" "error_code: $expected_error" "macOS $case_name 应命中 $expected_error"
    assert_contains "$case_dir/diagnostic.txt" "matched_rule: $expected_rule" "macOS $case_name 应命中规则 $expected_rule"
    assert_contains "$case_dir/diagnostic.txt" "human_title: $expected_title" "macOS $case_name 应输出标题 $expected_title"
    assert_contains "$case_dir/diagnostic.txt" "recommended_action:" "macOS $case_name 应输出建议动作"
    assert_contains "$case_dir/diagnostic.txt" "--- 规则化诊断结论 ---" "macOS $case_name 应写入规则化结论区块"

    echo "PASS: $case_name"
    pass_count=$((pass_count + 1))
}

run_windows_static_check() {
    print_header "Windows static"

    if ! command -v cmd.exe >/dev/null 2>&1 && ! command -v cmd >/dev/null 2>&1; then
        echo "SKIP: 当前环境没有可执行 .bat 的 cmd，跳过 Windows 运行验证"
        skip_count=$((skip_count + 1))
    fi

    assert_contains "$WIN_SCRIPT" "set \"ERROR_CODE=OK\"" "Windows 诊断脚本应初始化 ERROR_CODE"
    assert_contains "$WIN_SCRIPT" "echo error_code: %ERROR_CODE% >> \"%REPORT%\"" "Windows 诊断脚本应输出 error_code"
    assert_contains "$WIN_SCRIPT" "echo matched_rule: %MATCHED_RULE% >> \"%REPORT%\"" "Windows 诊断脚本应输出 matched_rule"
    assert_contains "$WIN_SCRIPT" "set \"MATCHED_RULE=R001\"" "Windows 诊断脚本应包含 R001 规则"
    assert_contains "$WIN_SCRIPT" "set \"MATCHED_RULE=R008\"" "Windows 诊断脚本应包含 R008 规则"
    assert_contains "$WIN_SCRIPT" "set \"MATCHED_RULE=R012\"" "Windows 诊断脚本应包含 R012 规则"

    echo "PASS: windows-static"
    pass_count=$((pass_count + 1))
}

run_mac_case "missing-node" "NODE_EMBEDDED_MISSING" "ENV_NODE_MISSING" "未找到内嵌 Node.js 运行时" "" "no" "no"
run_mac_case "missing-provider" "CONFIG_PROVIDER_MISSING" "CFG_PROVIDER_MISSING" "还没有完成模型配置" "" "yes" "no"
run_mac_case "git-ssh" "GIT_SSH_PERMISSION" "R001" "Git SSH 权限错误" $'Error: permission denied (publickey)\nfatal: Could not read from remote repository ssh://git@github.com/example/repo.git'
run_windows_static_check

printf '\nSummary: %s passed, %s skipped\n' "$pass_count" "$skip_count"
