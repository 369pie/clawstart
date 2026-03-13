#!/bin/bash
# ============================================================
# ClawStart macOS 免安装一键包 - 打包脚本
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/macos"
OUTPUT_DIR="$PROJECT_ROOT/dist"
VERSION="${1:-0.1.0}"

# 检测架构
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    NODE_ARCH="darwin-arm64"
    PACK_NAME="ClawStart-macOS-Apple-Silicon-v${VERSION}"
else
    NODE_ARCH="darwin-x64"
    PACK_NAME="ClawStart-macOS-Intel-v${VERSION}"
fi

NODE_VERSION="v22.12.0"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${CYAN}🦞 ClawStart macOS 一键包打包工具${NC}"
echo -e "   版本: ${VERSION} | 架构: ${ARCH}"
echo ""

# 清理
echo -e "  [1/6] 清理旧构建..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$PACK_NAME"
mkdir -p "$OUTPUT_DIR"

DEST="$BUILD_DIR/$PACK_NAME"

# 下载 Node.js
echo -e "  [2/6] 准备 Node.js 运行时..."
NODE_CACHE="$PROJECT_ROOT/build/.cache/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
if [ -f "$NODE_CACHE" ]; then
    echo -e "    使用缓存"
else
    echo -e "    下载 Node.js ${NODE_VERSION} (${NODE_ARCH})..."
    mkdir -p "$(dirname "$NODE_CACHE")"
    curl -L --progress-bar -o "$NODE_CACHE" "$NODE_URL"
fi

mkdir -p "$DEST/runtime/node"
tar xzf "$NODE_CACHE" -C /tmp
cp -r /tmp/node-${NODE_VERSION}-${NODE_ARCH}/* "$DEST/runtime/node/"
rm -rf /tmp/node-${NODE_VERSION}-${NODE_ARCH}
echo -e "  ${GREEN}✓${NC} Node.js 就绪"

# 安装 OpenClaw
echo -e "  [3/6] 安装 OpenClaw..."
mkdir -p "$DEST/openclaw"
export PATH="$DEST/runtime/node/bin:$PATH"
cd "$DEST/openclaw"
npm init -y >/dev/null 2>&1
npm install openclaw --save 2>&1 | tail -1 || {
    echo -e "  ${YELLOW}⚠ npm install 失败，标记为需要手动安装${NC}"
    echo "NEEDS_OPENCLAW_INSTALL=true" > "$DEST/.build-flags"
}
echo -e "  ${GREEN}✓${NC} OpenClaw 就绪"

# 复制启动器和工具
echo -e "  [4/6] 复制启动器..."
cp "$SCRIPT_DIR/launch.command" "$DEST/"
cp "$SCRIPT_DIR/diagnose.sh" "$DEST/"
chmod +x "$DEST/launch.command" "$DEST/diagnose.sh"

# 创建默认工作区
echo -e "  [5/6] 创建默认工作区..."
mkdir -p "$DEST/workspace"
mkdir -p "$DEST/config"

cat > "$DEST/workspace/AGENTS.md" << 'EOF'
# 我的 AI 工作区

欢迎使用 ClawStart！这是你的 AI 助手工作区。

## 快速开始
1. 双击 `launch.command` 启动 OpenClaw
2. 在浏览器中开始对话
3. 探索更多功能：https://clawstart.com
EOF

cat > "$DEST/README-先看这个.txt" << 'EOF'
🦞 ClawStart - OpenClaw 免安装一键包
   下载即运行，开箱就能用

【使用方法】
1. 双击 "launch.command" 启动
   - 首次可能需要：右键 → 打开（macOS 安全限制）
2. 首次运行会引导你配置 AI 模型
3. 配置完成后自动打开浏览器

【macOS 安全提示】
如果提示"无法打开，因为无法验证开发者"：
  方法1: 右键点击 launch.command → 选择"打开"
  方法2: 系统设置 → 隐私与安全性 → 仍要打开

【遇到问题？】
- 运行 diagnose.sh 生成诊断报告
- 将 diagnostic.txt 发到社群求助
- 访问 https://clawstart.com/troubleshooting

EOF

# 打包
echo -e "  [6/6] 打包..."
cd "$BUILD_DIR"
tar czf "$OUTPUT_DIR/${PACK_NAME}.tar.gz" "$PACK_NAME"
SIZE=$(du -sh "$OUTPUT_DIR/${PACK_NAME}.tar.gz" | cut -f1)
echo -e "  ${GREEN}✓${NC} 打包完成: dist/${PACK_NAME}.tar.gz (${SIZE})"

echo ""
echo -e "${GREEN}🦞 macOS 一键包构建完成！${NC}"
echo ""
