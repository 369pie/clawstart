#!/bin/bash
# ============================================================
# ClawStart Linux beta package builder
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/dist"
VERSION="${1:-0.1.0}"
TARGET_ARCH="${2:-x64}"

case "$TARGET_ARCH" in
    x64|x86_64|amd64)
        NODE_ARCH="linux-x64"
        PACK_NAME="ClawStart-Linux-x64-v${VERSION}"
        ;;
    arm64|aarch64)
        NODE_ARCH="linux-arm64"
        PACK_NAME="ClawStart-Linux-ARM64-v${VERSION}"
        ;;
    *)
        echo "Unsupported target arch: $TARGET_ARCH" >&2
        exit 1
        ;;
esac

DEST="$PROJECT_ROOT/build/linux/$PACK_NAME"
NODE_VERSION="v22.16.0"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
NPM_REGISTRY="${CLAWSTART_NPM_REGISTRY:-https://registry.npmjs.org}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

download_runtime() {
    local url="$1"
    local dest="$2"
    local tmp="${dest}.part"

    mkdir -p "$(dirname "$dest")"
    rm -f "$tmp"
    curl -fL --retry 3 --retry-delay 2 --progress-bar -o "$tmp" "$url"

    if [ ! -s "$tmp" ]; then
        echo "Failed to download runtime from: $url" >&2
        rm -f "$tmp"
        exit 1
    fi

    mv "$tmp" "$dest"
}

assert_bundled_node_matches_openclaw() {
    local package_json="$DEST/runtime/npm-global/lib/node_modules/openclaw/package.json"

    if [ ! -f "$package_json" ]; then
        echo "Missing OpenClaw package.json: $package_json" >&2
        exit 1
    fi

    if ! node - "$NODE_VERSION" "$package_json" <<'EOF'
const bundled = (process.argv[2] || "").replace(/^v/, "").trim();
const packageJsonPath = process.argv[3];
const pkg = require(packageJsonPath);
const requirement = String(pkg.engines?.node || "").trim();
const match = requirement.match(/^>=\s*(\d+)\.(\d+)\.(\d+)$/);

if (!match) {
  console.log(`  WARN OpenClaw engines.node is not a simple >=x.y.z range: ${requirement || "(missing)"}`);
  process.exit(0);
}

const parse = (value) => value.split(".").map((part) => Number.parseInt(part, 10) || 0);
const [bundledMajor, bundledMinor, bundledPatch] = parse(bundled);
const [requiredMajor, requiredMinor, requiredPatch] = match.slice(1).map((part) => Number.parseInt(part, 10));

const ok =
  bundledMajor > requiredMajor ||
  (bundledMajor === requiredMajor &&
    (bundledMinor > requiredMinor ||
      (bundledMinor === requiredMinor && bundledPatch >= requiredPatch)));

if (!ok) {
  console.error(`Bundled Node ${bundled} does not satisfy OpenClaw engines.node ${requirement}.`);
  process.exit(1);
}

console.log(`  OK Bundled Node ${bundled} satisfies OpenClaw engines.node ${requirement}`);
EOF
    then
        exit 1
    fi
}

echo ""
echo -e "${CYAN}ClawStart Linux beta package builder${NC}"
echo -e "  version: ${VERSION} | target: ${TARGET_ARCH} (${NODE_ARCH})"
echo ""

echo "  [1/6] Cleaning old build..."
rm -rf "$DEST"
mkdir -p "$DEST" "$OUTPUT_DIR"

echo "  [2/6] Preparing Node.js runtime..."
NODE_CACHE="$PROJECT_ROOT/build/.cache/node-${NODE_VERSION}-${NODE_ARCH}.tar.gz"
if [ ! -f "$NODE_CACHE" ]; then
    download_runtime "$NODE_URL" "$NODE_CACHE"
fi

if [ ! -s "$NODE_CACHE" ]; then
    echo "Missing Node.js runtime archive: $NODE_CACHE" >&2
    exit 1
fi

mkdir -p "$DEST/runtime/node"
rm -rf /tmp/clawstart-node-linux-extract
mkdir -p /tmp/clawstart-node-linux-extract
tar xzf "$NODE_CACHE" -C /tmp/clawstart-node-linux-extract
cp -R /tmp/clawstart-node-linux-extract/node-${NODE_VERSION}-${NODE_ARCH}/. "$DEST/runtime/node/"
rm -rf /tmp/clawstart-node-linux-extract
echo -e "  ${GREEN}OK${NC} Node.js runtime ready"

echo "  [3/6] Installing OpenClaw into local bundle prefix..."
mkdir -p "$DEST/runtime/npm-global"
npm install -g openclaw --prefix "$DEST/runtime/npm-global" --omit=dev --registry "$NPM_REGISTRY"
echo -e "  ${GREEN}OK${NC} OpenClaw installed"
assert_bundled_node_matches_openclaw

echo "  [4/6] Copying launch tools..."
cp "$SCRIPT_DIR/launch.sh" "$DEST/"
cp "$SCRIPT_DIR/gateway-runner.sh" "$DEST/"
cp "$SCRIPT_DIR/diagnose.sh" "$DEST/"
chmod +x "$DEST/launch.sh" "$DEST/gateway-runner.sh" "$DEST/diagnose.sh"

# Config wizard (web UI)
mkdir -p "$DEST/config-wizard"
cp "$SCRIPT_DIR/config-wizard/config-server.mjs" "$DEST/config-wizard/"
cp "$SCRIPT_DIR/config-wizard/index.html" "$DEST/config-wizard/"
cp "$SCRIPT_DIR/config-wizard/providers.json" "$DEST/config-wizard/"

echo "  [5/6] Creating default workspace..."
mkdir -p "$DEST/workspace" "$DEST/state" "$DEST/logs"

cat > "$DEST/workspace/AGENTS.md" <<'EOF'
# ClawStart Workspace

Welcome to your ClawStart workspace.

## First run
1. Run `./launch.sh`
2. Complete the OpenClaw setup wizard
3. Return here when you want the agent to work with your files
EOF

cat > "$DEST/README.txt" <<'EOF'
ClawStart Linux Beta
====================

使用方法
1. 打开终端，cd 到此目录
2. chmod +x launch.sh && ./launch.sh
3. 首次运行在浏览器中完成配置向导
4. 浏览器会自动打开本地控制台 http://127.0.0.1:18789

遇到问题
- 运行 ./diagnose.sh 生成诊断报告
- 访问 https://useclawstart.com/troubleshooting.html

目录说明
- runtime/ : 内嵌 Node.js 和 OpenClaw CLI
- config-wizard/ : 配置向导 Web UI
- workspace/ : 默认工作区
- state/ : 本地配置和状态
- logs/ : 启动日志
EOF

echo "  [6/6] Validating package contents..."
required_files=(
    "$DEST/launch.sh"
    "$DEST/gateway-runner.sh"
    "$DEST/diagnose.sh"
    "$DEST/README.txt"
    "$DEST/runtime/node/bin/node"
    "$DEST/runtime/npm-global/lib/node_modules/openclaw/openclaw.mjs"
    "$DEST/config-wizard/config-server.mjs"
    "$DEST/config-wizard/index.html"
    "$DEST/config-wizard/providers.json"
)

for required in "${required_files[@]}"; do
    if [ ! -f "$required" ]; then
        echo "Missing required package file: $required" >&2
        exit 1
    fi
done
echo -e "  ${GREEN}OK${NC} Validation passed"

echo "  [7/7] Packing archive..."
ARCHIVE="$OUTPUT_DIR/${PACK_NAME}.tar.gz"
tar czf "$ARCHIVE" -C "$(dirname "$DEST")" "$(basename "$DEST")"
echo ""
echo -e "Built: ${GREEN}${ARCHIVE}${NC}"
echo ""
