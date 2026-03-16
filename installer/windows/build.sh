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

NODE_VERSION="v22.16.0"
NODE_ARCH="win-x64"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-${NODE_ARCH}.zip"
NPM_REGISTRY="${CLAWSTART_NPM_REGISTRY:-https://registry.npmjs.org}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Convert a UTF-8 bat file to UTF-8 BOM + CRLF for correct Windows CMD handling.
# Without BOM, chcp 65001 causes cmd.exe file-pointer desync on CJK Windows,
# resulting in garbled commands and instant exit.
prepare_bat_for_windows() {
    local src="$1"
    local dst="$2"
    local tmp="${dst}.tmp"
    # Add UTF-8 BOM (EF BB BF) then convert LF → CRLF
    printf '\xEF\xBB\xBF' > "$tmp"
    sed 's/$/\r/' "$src" >> "$tmp"
    mv "$tmp" "$dst"
}

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
echo -e "${CYAN}ClawStart Windows beta package builder${NC}"
echo -e "  version: ${VERSION}"
echo ""

echo "  [1/6] Cleaning old build..."
rm -rf "$DEST"
mkdir -p "$DEST" "$OUTPUT_DIR"

echo "  [2/6] Preparing Node.js runtime..."
NODE_CACHE="$PROJECT_ROOT/build/.cache/node-${NODE_VERSION}-${NODE_ARCH}.zip"
if [ ! -f "$NODE_CACHE" ]; then
    download_runtime "$NODE_URL" "$NODE_CACHE"
fi

if [ ! -s "$NODE_CACHE" ]; then
    echo "Missing Node.js runtime archive: $NODE_CACHE" >&2
    exit 1
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
assert_bundled_node_matches_openclaw

echo "  [4/6] Copying launch tools..."
prepare_bat_for_windows "$SCRIPT_DIR/launch.bat" "$DEST/launch.bat"
prepare_bat_for_windows "$SCRIPT_DIR/first-run.bat" "$DEST/first-run.bat"
prepare_bat_for_windows "$SCRIPT_DIR/diagnose.bat" "$DEST/diagnose.bat"
prepare_bat_for_windows "$SCRIPT_DIR/gateway-runner.bat" "$DEST/gateway-runner.bat"

mkdir -p "$DEST/config-wizard"
cp "$SCRIPT_DIR/config-wizard/config-server.mjs" "$DEST/config-wizard/config-server.mjs"
cp "$SCRIPT_DIR/config-wizard/index.html" "$DEST/config-wizard/index.html"
cp "$SCRIPT_DIR/config-wizard/providers.json" "$DEST/config-wizard/providers.json"
echo -e "  ${GREEN}OK${NC} Config wizard copied"

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

cat > "$DEST/README.txt" <<'EOF'
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
- config-wizard/ : 配置向导（首次运行自动打开）
- workspace/ : 默认工作区
- state/ : 本地配置和状态
- logs/ : 启动日志
EOF

echo "  [6/6] Validating package contents..."
required_files=(
    "$DEST/launch.bat"
    "$DEST/first-run.bat"
    "$DEST/diagnose.bat"
    "$DEST/gateway-runner.bat"
    "$DEST/README.txt"
    "$DEST/runtime/node/node.exe"
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

if find "$DEST" -print | LC_ALL=C grep -q '[^ -~]'; then
    echo "Non-ASCII file or directory names found in Windows package." >&2
    find "$DEST" -print | LC_ALL=C grep '[^ -~]' >&2 || true
    exit 1
fi

echo "  [7/7] Packing archive..."
(
    cd "$PROJECT_ROOT/build/windows"
    zip -qr "$OUTPUT_DIR/${PACK_NAME}.zip" "$PACK_NAME"
)

echo ""
echo -e "${GREEN}Built:${NC} dist/${PACK_NAME}.zip"
echo ""
