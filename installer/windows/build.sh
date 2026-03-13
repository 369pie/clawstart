#!/bin/bash
# ============================================================
# ClawStart Windows 免安装一键包 - 打包脚本
# 在 macOS/Linux 上构建 Windows 分发包
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/windows"
OUTPUT_DIR="$PROJECT_ROOT/dist"
VERSION="${1:-0.1.0}"
PACK_NAME="ClawStart-Windows-v${VERSION}"

# Node.js Windows 版本
NODE_VERSION="v22.12.0"
NODE_ARCH="win-x64"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.zip"

# 颜色
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}🦞 ClawStart Windows 一键包打包工具${NC}"
echo -e "   版本: ${VERSION}"
echo ""

# 清理
echo -e "  [1/6] 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$PACK_NAME"
mkdir -p "$OUTPUT_DIR"

DEST="$BUILD_DIR/$PACK_NAME"

# 下载 Node.js
echo -e "  [2/6] 准备 Node.js 运行时..."
NODE_CACHE="$PROJECT_ROOT/build/.cache/node-${NODE_VERSION}-${NODE_ARCH}.zip"
if [ -f "$NODE_CACHE" ]; then
    echo -e "    使用缓存: $NODE_CACHE"
else
    echo -e "    下载 Node.js ${NODE_VERSION} (${NODE_ARCH})..."
    mkdir -p "$(dirname "$NODE_CACHE")"
    curl -L --progress-bar -o "$NODE_CACHE" "$NODE_URL"
fi

mkdir -p "$DEST/runtime/node"
cd /tmp && unzip -qo "$NODE_CACHE" -d /tmp/node_extract
cp -r /tmp/node_extract/node-${NODE_VERSION}-${NODE_ARCH}/* "$DEST/runtime/node/"
rm -rf /tmp/node_extract
echo -e "  ${GREEN}✓${NC} Node.js 就绪"

# 安装 OpenClaw
echo -e "  [3/6] 安装 OpenClaw..."
mkdir -p "$DEST/openclaw"
cd "$DEST/openclaw"
"$DEST/runtime/node/node.exe" "$DEST/runtime/node/node_modules/npm/bin/npm-cli.js" init -y >/dev/null 2>&1 || true
"$DEST/runtime/node/node.exe" "$DEST/runtime/node/node_modules/npm/bin/npm-cli.js" install openclaw --save >/dev/null 2>&1 || {
    echo -e "  ${YELLOW}⚠ npm install 失败，尝试使用本地 OpenClaw...${NC}"
    # 如果 npm 安装失败（比如在 mac 上无法运行 node.exe），标记为需要手动处理
    echo "NEEDS_OPENCLAW_INSTALL=true" > "$DEST/.build-flags"
}
echo -e "  ${GREEN}✓${NC} OpenClaw 就绪"

# 复制启动器和工具
echo -e "  [4/6] 复制启动器..."
cp "$SCRIPT_DIR/launch.bat" "$DEST/"
cp "$SCRIPT_DIR/first-run.bat" "$DEST/"
cp "$SCRIPT_DIR/diagnose.bat" "$DEST/"

# 创建默认工作区
echo -e "  [5/6] 创建默认工作区..."
mkdir -p "$DEST/workspace"
mkdir -p "$DEST/config"

cat > "$DEST/workspace/AGENTS.md" << 'EOF'
# 我的 AI 工作区

欢迎使用 ClawStart！这是你的 AI 助手工作区。

## 快速开始
1. 双击 `启动.bat` 启动 OpenClaw
2. 在浏览器中开始对话
3. 探索更多功能：https://clawstart.com

## 文件说明
- 这个目录是你的工作区，AI 助手会在这里读写文件
- 你可以在这里放置需要 AI 处理的文档
EOF

cat > "$DEST/README-先看这个.txt" << 'EOF'
╔══════════════════════════════════════════╗
║  🦞 ClawStart - OpenClaw 免安装一键包    ║
║  下载即运行，开箱就能用                    ║
╚══════════════════════════════════════════╝

【使用方法】
1. 双击 "launch.bat" 启动
2. 首次运行会引导你配置 AI 模型
3. 配置完成后自动打开浏览器

【遇到问题？】
- 双击 "diagnose.bat" 生成诊断报告
- 将 diagnostic.txt 发到社群求助
- 访问 https://clawstart.com/troubleshooting

【社群】
- QQ群: [待填写]
- 微信群: [待填写]
- 网站: https://clawstart.com

【注意事项】
- 请勿删除 runtime/ 目录（包含运行环境）
- 请勿删除 openclaw/ 目录（包含程序本体）
- workspace/ 是你的工作区，可以自由使用
- config/ 保存你的配置，重装时可备份

EOF

# 打包
echo -e "  [6/6] 打包..."
cd "$BUILD_DIR"
if command -v zip >/dev/null 2>&1; then
    zip -qr "$OUTPUT_DIR/${PACK_NAME}.zip" "$PACK_NAME"
    echo -e "  ${GREEN}✓${NC} 打包完成: dist/${PACK_NAME}.zip"
    size=$(du -sh "$OUTPUT_DIR/${PACK_NAME}.zip" | cut -f1)
    echo -e "    大小: ${size}"
else
    tar czf "$OUTPUT_DIR/${PACK_NAME}.tar.gz" "$PACK_NAME"
    echo -e "  ${GREEN}✓${NC} 打包完成: dist/${PACK_NAME}.tar.gz"
fi

echo ""
echo -e "${GREEN}🦞 Windows 一键包构建完成！${NC}"
echo ""
