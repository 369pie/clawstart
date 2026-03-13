#!/bin/bash
# ============================================================
# ClawStart Windows beta package builder
# Builds a downloadable Windows bundle from macOS/Linux
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/dist"
VERSION="${1:-0.1.0}"
PACK_NAME="ClawStart-Windows-v${VERSION}"
DEST="$PROJECT_ROOT/build/windows/$PACK_NAME"

NODE_VERSION="v22.12.0"
NODE_ARCH="win-x64"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.zip"
NPM_REGISTRY="${CLAWSTART_NPM_REGISTRY:-https://registry.npmjs.org}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}ClawStart Windows beta package builder${NC}"
echo -e "  version: ${VERSION}"
echo ""

echo "  [1/6] Cleaning old build..."
rm -rf "$DEST"
mkdir -p "$DEST" "$OUTPUT_DIR"

echo "  [2/6] Preparing Node.js runtime..."
NODE_CACHE="$PROJECT_ROOT/build/.cache/node-${NODE_VERSION}-${NODE_ARCH}.zip"
if [ ! -f "$NODE_CACHE" ]; then
    mkdir -p "$(dirname "$NODE_CACHE")"
    curl -L --progress-bar -o "$NODE_CACHE" "$NODE_URL"
fi

mkdir -p "$DEST/runtime/node"
rm -rf /tmp/clawstart-node-win-extract
mkdir -p /tmp/clawstart-node-win-extract
unzip -qo "$NODE_CACHE" -d /tmp/clawstart-node-win-extract
cp -R /tmp/clawstart-node-win-extract/node-${NODE_VERSION}-${NODE_ARCH}/. "$DEST/runtime/node/"
rm -rf /tmp/clawstart-node-win-extract
echo -e "  ${GREEN}OK${NC} Node.js runtime ready"

echo "  [3/6] Installing OpenClaw into local bundle prefix..."
mkdir -p "$DEST/runtime/npm-global"
npm_config_platform=win32 \
npm_config_arch=x64 \
npm install -g openclaw --prefix "$DEST/runtime/npm-global" --omit=dev --registry "$NPM_REGISTRY"
echo -e "  ${GREEN}OK${NC} OpenClaw installed"

echo "  [4/6] Copying launch tools..."
cp "$SCRIPT_DIR/launch.bat" "$DEST/"
cp "$SCRIPT_DIR/first-run.bat" "$DEST/"
cp "$SCRIPT_DIR/diagnose.bat" "$DEST/"

echo "  [5/6] Creating default workspace..."
mkdir -p "$DEST/workspace" "$DEST/state" "$DEST/logs"

cat > "$DEST/workspace/AGENTS.md" <<'EOF'
# ClawStart Workspace

Welcome to your ClawStart workspace.

## First run
1. Double-click `launch.bat`
2. Finish the OpenClaw setup wizard
3. Return here when you want the agent to work with your files

## Notes
- This folder is your default workspace
- Files you want OpenClaw to read or edit can live here
- The package keeps its own state under the local `state/` directory
EOF

cat > "$DEST/README-先看这个.txt" <<'EOF'
ClawStart Windows Beta
======================

使用方法
1. 双击 launch.bat
2. 首次运行按提示完成 OpenClaw 配置向导
3. 浏览器会自动打开本地控制台

遇到问题
- 双击 diagnose.bat 生成诊断报告
- 访问 https://useclawstart.com/troubleshooting.html

目录说明
- runtime/ : 内嵌 Node.js 和 OpenClaw CLI
- workspace/ : 默认工作区
- state/ : 本地配置和状态
- logs/ : 启动日志
EOF

echo "  [6/6] Packing archive..."
(
    cd "$PROJECT_ROOT/build/windows"
    zip -qr "$OUTPUT_DIR/${PACK_NAME}.zip" "$PACK_NAME"
)

echo ""
echo -e "${GREEN}Built:${NC} dist/${PACK_NAME}.zip"
echo ""
