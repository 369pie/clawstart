#!/bin/bash
# ============================================================
# ClawStart macOS beta package builder
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/dist"
VERSION="${1:-0.1.0}"
TARGET_ARCH="${2:-$(uname -m)}"

case "$TARGET_ARCH" in
    arm64|aarch64)
        NODE_ARCH="darwin-arm64"
        PACK_NAME="ClawStart-macOS-Apple-Silicon-v${VERSION}"
        ;;
    x64|x86_64|intel)
        NODE_ARCH="darwin-x64"
        PACK_NAME="ClawStart-macOS-Intel-v${VERSION}"
        ;;
    *)
        echo "Unsupported target arch: $TARGET_ARCH" >&2
        exit 1
        ;;
esac

DEST="$PROJECT_ROOT/build/macos/$PACK_NAME"
NODE_VERSION="v22.12.0"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
NPM_REGISTRY="${CLAWSTART_NPM_REGISTRY:-https://registry.npmjs.org}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}ClawStart macOS beta package builder${NC}"
echo -e "  version: ${VERSION} | target: ${TARGET_ARCH}"
echo ""

echo "  [1/6] Cleaning old build..."
rm -rf "$DEST"
mkdir -p "$DEST" "$OUTPUT_DIR"

echo "  [2/6] Preparing Node.js runtime..."
NODE_CACHE="$PROJECT_ROOT/build/.cache/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
if [ ! -f "$NODE_CACHE" ]; then
    mkdir -p "$(dirname "$NODE_CACHE")"
    curl -L --progress-bar -o "$NODE_CACHE" "$NODE_URL"
fi

mkdir -p "$DEST/runtime/node"
rm -rf /tmp/clawstart-node-macos-extract
mkdir -p /tmp/clawstart-node-macos-extract
tar xzf "$NODE_CACHE" -C /tmp/clawstart-node-macos-extract
cp -R /tmp/clawstart-node-macos-extract/node-${NODE_VERSION}-${NODE_ARCH}/. "$DEST/runtime/node/"
rm -rf /tmp/clawstart-node-macos-extract
echo -e "  ${GREEN}OK${NC} Node.js runtime ready"

echo "  [3/6] Installing OpenClaw into local bundle prefix..."
mkdir -p "$DEST/runtime/npm-global"
npm_config_platform=darwin \
npm_config_arch="${TARGET_ARCH/arm64/arm64}" \
npm install -g openclaw --prefix "$DEST/runtime/npm-global" --omit=dev --registry "$NPM_REGISTRY"
echo -e "  ${GREEN}OK${NC} OpenClaw installed"

echo "  [4/6] Copying launch tools..."
cp "$SCRIPT_DIR/launch.command" "$DEST/"
cp "$SCRIPT_DIR/diagnose.sh" "$DEST/"
chmod +x "$DEST/launch.command" "$DEST/diagnose.sh"

echo "  [5/6] Creating default workspace..."
mkdir -p "$DEST/workspace" "$DEST/state" "$DEST/logs"

cat > "$DEST/workspace/AGENTS.md" <<'EOF'
# ClawStart Workspace

Welcome to your ClawStart workspace.

## First run
1. Double-click `launch.command`
2. Complete the OpenClaw setup wizard
3. Return here when you want the agent to work with your files
EOF

cat > "$DEST/README-先看这个.txt" <<'EOF'
ClawStart macOS Beta
====================

使用方法
1. 双击 launch.command
2. 首次运行按提示完成 OpenClaw 配置向导
3. 浏览器会自动打开本地控制台

如果 macOS 提示无法打开
- 右键 launch.command -> 打开
- 或在 系统设置 -> 隐私与安全性 中允许

遇到问题
- 运行 diagnose.sh 生成诊断报告
- 访问 https://useclawstart.com/troubleshooting.html

目录说明
- runtime/ : 内嵌 Node.js 和 OpenClaw CLI
- workspace/ : 默认工作区
- state/ : 本地配置和状态
- logs/ : 启动日志
EOF

echo "  [6/6] Packing archive..."
(
    cd "$PROJECT_ROOT/build/macos"
    tar czf "$OUTPUT_DIR/${PACK_NAME}.tar.gz" "$PACK_NAME"
)

echo ""
echo -e "${GREEN}Built:${NC} dist/${PACK_NAME}.tar.gz"
echo ""
