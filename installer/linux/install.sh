#!/bin/bash
set -euo pipefail

SCRIPT_NAME="ClawStart Linux Beta Installer"
CLAWSTART_HOME="${CLAWSTART_HOME:-$HOME/.clawstart-linux-beta}"
NPM_PREFIX="$CLAWSTART_HOME/runtime/npm-global"
WORKSPACE_DIR="$CLAWSTART_HOME/workspace"
CONFIG_DIR="$CLAWSTART_HOME/config"
LOGS_DIR="$CLAWSTART_HOME/logs"
NPM_REGISTRY="${CLAWSTART_NPM_REGISTRY:-https://registry.npmmirror.com}"
PACKAGE_NAME="${CLAWSTART_NPM_PACKAGE:-openclaw}"
NODE_BIN="${CLAWSTART_NODE_BIN:-node}"
NPM_BIN="${CLAWSTART_NPM_BIN:-npm}"
PACKAGE_MANAGER_OVERRIDE="${CLAWSTART_PM_OVERRIDE:-}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "${CYAN}[ClawStart Linux Beta]${NC} $1"
}

fail() {
    echo -e "${YELLOW}安装中止：$1${NC}" >&2
    exit 1
}

detect_pm() {
    if [ -n "$PACKAGE_MANAGER_OVERRIDE" ]; then
        echo "$PACKAGE_MANAGER_OVERRIDE"
        return
    fi

    for pm in apt-get dnf yum pacman zypper apk; do
        if command -v "$pm" >/dev/null 2>&1; then
            echo "$pm"
            return
        fi
    done
    echo "unknown"
}

node_major_version() {
    if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
        echo "0"
        return
    fi

    "$NODE_BIN" -v 2>/dev/null | sed 's/^v//' | cut -d. -f1
}

print_node_instructions() {
    local pm="$1"

    echo ""
    echo "当前需要 Node.js 20 或更高版本。你可以先按下面命令安装，再重新运行本脚本："
    case "$pm" in
        apt-get)
            cat <<'EOF'
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
EOF
            ;;
        dnf|yum)
            cat <<'EOF'
sudo dnf install -y nodejs npm
EOF
            ;;
        pacman)
            cat <<'EOF'
sudo pacman -S --needed nodejs npm
EOF
            ;;
        zypper)
            cat <<'EOF'
sudo zypper install -y nodejs20 npm20
EOF
            ;;
        apk)
            cat <<'EOF'
sudo apk add nodejs npm
EOF
            ;;
        *)
            cat <<'EOF'
请先安装 Node.js 20+ 和 npm，再重新执行本脚本。
EOF
            ;;
    esac
}

write_workspace_files() {
    mkdir -p "$WORKSPACE_DIR" "$CONFIG_DIR" "$LOGS_DIR" "$NPM_PREFIX"

    cat > "$WORKSPACE_DIR/AGENTS.md" <<'EOF'
# 我的 ClawStart Linux 工作区

欢迎使用 ClawStart Linux Beta。

## 你现在可以做什么
1. 运行 `launch.sh`
2. 按终端提示完成模型配置
3. 如果失败，先看 https://369pie.github.io/clawstart/troubleshooting.html
EOF

    cat > "$CLAWSTART_HOME/launch.sh" <<EOF
#!/bin/bash
set -euo pipefail
export PATH="$NPM_PREFIX/bin:\$PATH"
export CLAWSTART_HOME="$CLAWSTART_HOME"
cd "$WORKSPACE_DIR"
exec openclaw start "\$@"
EOF

    cat > "$CLAWSTART_HOME/README.txt" <<'EOF'
ClawStart Linux Beta
====================

这是面向 Linux 用户的实验性安装路径。

下一步：
1. 运行 ./launch.sh
2. 按提示完成模型配置
3. 如果卡在权限、Git、网络或 npm 错误，先看排障页：
   https://369pie.github.io/clawstart/troubleshooting.html

说明：
- 安装内容默认放在 ~/.clawstart-linux-beta
- 当前更适合熟悉终端、愿意自己排错的用户
- 普通用户优先建议使用 Windows 或 macOS 一键包
EOF

    chmod +x "$CLAWSTART_HOME/launch.sh"
}

install_openclaw() {
    print_step "正在安装底层 OpenClaw CLI 到本地 Beta 目录..."
    "$NPM_BIN" install -g "$PACKAGE_NAME" --prefix "$NPM_PREFIX" --registry "$NPM_REGISTRY"
}

main() {
    print_step "$SCRIPT_NAME"
    print_step "安装目录: $CLAWSTART_HOME"

    local pm
    pm="$(detect_pm)"
    local node_major
    node_major="$(node_major_version)"

    if [ "$node_major" -lt 20 ]; then
        print_node_instructions "$pm"
        fail "未检测到可用的 Node.js 20+ 环境。"
    fi

    mkdir -p "$CLAWSTART_HOME"
    write_workspace_files
    install_openclaw

    echo ""
    echo -e "${GREEN}安装完成。${NC}"
    echo "下一步："
    echo "  1. cd \"$CLAWSTART_HOME\""
    echo "  2. ./launch.sh"
    echo "  3. 如遇问题，查看 https://369pie.github.io/clawstart/troubleshooting.html"
}

main "$@"
