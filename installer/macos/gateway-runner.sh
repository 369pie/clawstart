#!/bin/bash
# ============================================================
# ClawStart macOS gateway runner (background helper)
# ============================================================

CLAWSTART_HOME="$(cd "$(dirname "$0")" && pwd)"
NODE_BIN="$CLAWSTART_HOME/runtime/node/bin/node"
OPENCLAW_CLI="$CLAWSTART_HOME/runtime/npm-global/lib/node_modules/openclaw/openclaw.mjs"
STATE_DIR="$CLAWSTART_HOME/state"
CONFIG_FILE="$STATE_DIR/openclaw.json"
LOGS_DIR="$CLAWSTART_HOME/logs"
GATEWAY_LOG="$LOGS_DIR/gateway.log"
GATEWAY_PORT=18789

mkdir -p "$LOGS_DIR"

if [ ! -x "$NODE_BIN" ]; then
    echo "[gateway-runner] missing embedded Node.js: $NODE_BIN" >>"$GATEWAY_LOG"
    exit 1
fi

if [ ! -f "$OPENCLAW_CLI" ]; then
    echo "[gateway-runner] missing OpenClaw CLI: $OPENCLAW_CLI" >>"$GATEWAY_LOG"
    exit 1
fi

cd "$CLAWSTART_HOME"
export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CONFIG_FILE"
export OPENCLAW_HOME="$CLAWSTART_HOME"
export PATH="$CLAWSTART_HOME/runtime/node/bin:$PATH"

# Read gateway auth token from portable config and export as env var
if [ -f "$CONFIG_FILE" ]; then
    TOKEN=$("$NODE_BIN" -e "try{const c=JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));if(c.gateway?.auth?.token)process.stdout.write(c.gateway.auth.token)}catch{}" 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        export OPENCLAW_GATEWAY_TOKEN="$TOKEN"
        echo "[gateway-runner] loaded token from portable config" >>"$GATEWAY_LOG"
    fi
fi

echo "[gateway-runner] starting OpenClaw gateway" >>"$GATEWAY_LOG"
"$NODE_BIN" "$OPENCLAW_CLI" gateway run --port "$GATEWAY_PORT" --bind loopback --allow-unconfigured --force >>"$GATEWAY_LOG" 2>&1
EXIT_CODE=$?
echo "[gateway-runner] OpenClaw gateway exited with code $EXIT_CODE" >>"$GATEWAY_LOG"
exit $EXIT_CODE
