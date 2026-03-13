#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/installer/linux/install.sh"
TMP_BASE="$(mktemp -d /tmp/clawstart-linux-fixtures.XXXXXX)"

cleanup() {
    rm -rf "$TMP_BASE"
}
trap cleanup EXIT

pass_count=0

print_header() {
    printf '\n[%s]\n' "$1"
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    if ! grep -Fq -- "$pattern" "$file"; then
        echo "FAIL: $message"
        echo "  file: $file"
        echo "  expected: $pattern"
        exit 1
    fi
}

run_success_case() {
    local case_dir="$TMP_BASE/success"
    local fake_bin="$case_dir/fake-bin"
    local home_dir="$case_dir/home"
    local install_home="$case_dir/clawstart-home"
    mkdir -p "$fake_bin" "$home_dir"

    cat > "$fake_bin/fake-node" <<'EOF'
#!/bin/bash
echo v20.11.0
EOF

    cat > "$fake_bin/fake-npm" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" > "${CLAWSTART_FIXTURE_LOG:?}"
prefix=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--prefix" ]; then
        prefix="$2"
        shift 2
        continue
    fi
    shift
done
mkdir -p "$prefix/bin"
cat > "$prefix/bin/openclaw" <<'INNER'
#!/bin/bash
echo "fake openclaw"
INNER
chmod +x "$prefix/bin/openclaw"
EOF

    chmod +x "$fake_bin/fake-node" "$fake_bin/fake-npm"

    print_header "linux-success"
    CLAWSTART_HOME="$install_home" \
    HOME="$home_dir" \
    PATH="$fake_bin:$PATH" \
    CLAWSTART_NODE_BIN="fake-node" \
    CLAWSTART_NPM_BIN="fake-npm" \
    CLAWSTART_FIXTURE_LOG="$case_dir/npm.log" \
    CLAWSTART_PM_OVERRIDE="apt-get" \
    bash "$INSTALL_SCRIPT" >/dev/null

    assert_contains "$case_dir/npm.log" "install -g openclaw --prefix $install_home/runtime/npm-global --registry https://registry.npmmirror.com" "Linux success 应调用 npm 安装 openclaw"
    assert_contains "$install_home/README.txt" "ClawStart Linux Beta" "Linux success 应生成 README"
    assert_contains "$install_home/workspace/AGENTS.md" "欢迎使用 ClawStart Linux Beta。" "Linux success 应生成工作区说明"
    assert_contains "$install_home/launch.sh" "exec openclaw start" "Linux success 应生成 launch.sh"

    echo "PASS: linux-success"
    pass_count=$((pass_count + 1))
}

run_missing_node_case() {
    local case_dir="$TMP_BASE/missing-node"
    local output_file="$case_dir/output.txt"
    mkdir -p "$case_dir"

    print_header "linux-missing-node"
    set +e
    CLAWSTART_HOME="$case_dir/clawstart-home" \
    HOME="$case_dir/home" \
    PATH="/usr/bin:/bin" \
    CLAWSTART_NODE_BIN="definitely-missing-node" \
    CLAWSTART_PM_OVERRIDE="apt-get" \
    bash "$INSTALL_SCRIPT" >"$output_file" 2>&1
    local status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo "FAIL: Linux missing-node 应失败退出"
        exit 1
    fi

    assert_contains "$output_file" "当前需要 Node.js 20 或更高版本。" "Linux missing-node 应提示 Node.js 版本要求"
    assert_contains "$output_file" "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -" "Linux missing-node 应给出 apt 安装提示"
    assert_contains "$output_file" "安装中止：未检测到可用的 Node.js 20+ 环境。" "Linux missing-node 应输出终止原因"

    echo "PASS: linux-missing-node"
    pass_count=$((pass_count + 1))
}

run_success_case
run_missing_node_case

printf '\nSummary: %s passed\n' "$pass_count"
