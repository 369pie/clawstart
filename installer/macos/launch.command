#!/bin/bash
# ============================================================
# ClawStart macOS beta launcher
# ============================================================

set -euo pipefail

CLAWSTART_HOME="$(cd "$(dirname "$0")" && pwd)"
NODE_BIN="$CLAWSTART_HOME/runtime/node/bin/node"
OPENCLAW_CLI="$CLAWSTART_HOME/runtime/npm-global/node_modules/openclaw/openclaw.mjs"
STATE_DIR="$CLAWSTART_HOME/state"
CONFIG_FILE="$STATE_DIR/openclaw.json"
WORKSPACE_DIR="$CLAWSTART_HOME/workspace"
LOGS_DIR="$CLAWSTART_HOME/logs"
GATEWAY_PORT="${CLAWSTART_PORT:-3000}"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR" "$LOGS_DIR"

export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CONFIG_FILE"
export OPENCLAW_HOME="$CLAWSTART_HOME"
export PATH="$CLAWSTART_HOME/runtime/node/bin:$PATH"

echo ""
echo "ClawStart macOS Beta"
echo "下载即运行，开箱就能用"
echo ""

if [ ! -x "$NODE_BIN" ]; then
  echo "未找到内嵌 Node.js，请重新下载完整的一键包。"
  exit 1
fi

if [ ! -f "$OPENCLAW_CLI" ]; then
  echo "未找到 OpenClaw CLI，请重新下载完整的一键包。"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "检测到首次运行，正在启动 OpenClaw 配置向导..."
  "$NODE_BIN" "$OPENCLAW_CLI" setup --wizard --mode local --workspace "$WORKSPACE_DIR"
fi

echo "正在启动 OpenClaw..."
"$NODE_BIN" "$OPENCLAW_CLI" gateway run --port "$GATEWAY_PORT" --bind loopback --allow-unconfigured --force >"$LOGS_DIR/gateway.log" 2>&1 &
PID=$!

READY=0
for _ in $(seq 1 30); do
  sleep 1
  if curl -s -o /dev/null "http://127.0.0.1:$GATEWAY_PORT"; then
    READY=1
    break
  fi
done

if [ "$READY" -ne 1 ]; then
  echo "启动超时，请查看 logs/gateway.log"
  kill "$PID" 2>/dev/null || true
  exit 1
fi

echo "OpenClaw 已启动: http://127.0.0.1:$GATEWAY_PORT"
open "http://127.0.0.1:$GATEWAY_PORT"
echo "关闭此窗口将停止当前会话。"
wait "$PID"
