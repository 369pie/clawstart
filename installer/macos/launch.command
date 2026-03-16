#!/bin/bash
# ============================================================
# ClawStart macOS beta launcher
# ============================================================

set -euo pipefail

CLAWSTART_HOME="$(cd "$(dirname "$0")" && pwd)"
NODE_BIN="$CLAWSTART_HOME/runtime/node/bin/node"
OPENCLAW_CLI="$CLAWSTART_HOME/runtime/npm-global/lib/node_modules/openclaw/openclaw.mjs"
STATE_DIR="$CLAWSTART_HOME/state"
CONFIG_FILE="$STATE_DIR/openclaw.json"
WORKSPACE_DIR="$CLAWSTART_HOME/workspace"
LOGS_DIR="$CLAWSTART_HOME/logs"
GATEWAY_LOG="$LOGS_DIR/gateway.log"
LAUNCHER_LOG="$LOGS_DIR/launcher.log"
GATEWAY_PORT=18789
WIZARD_PORT=18790
GATEWAY_RUNNER="$CLAWSTART_HOME/gateway-runner.sh"
CONFIG_WIZARD="$CLAWSTART_HOME/config-wizard/config-server.mjs"

mkdir -p "$STATE_DIR" "$WORKSPACE_DIR" "$LOGS_DIR"
: > "$LAUNCHER_LOG"

export OPENCLAW_STATE_DIR="$STATE_DIR"
export OPENCLAW_CONFIG_PATH="$CONFIG_FILE"
export OPENCLAW_HOME="$CLAWSTART_HOME"
export PATH="$CLAWSTART_HOME/runtime/node/bin:$PATH"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LAUNCHER_LOG"; }

echo ""
echo "  ClawStart macOS Beta"
echo "  下载即运行，开箱就能用"
echo ""

# ── [1/4] 环境检查 ──
log "launcher started from $CLAWSTART_HOME"

if [ ! -x "$NODE_BIN" ]; then
    echo "[错误] 未找到内嵌 Node.js"
    echo "请重新下载完整的一键包"
    exit 1
fi

if [ ! -f "$OPENCLAW_CLI" ]; then
    echo "[错误] 未找到 OpenClaw CLI"
    echo "请重新下载完整的一键包"
    exit 1
fi

if [ ! -f "$GATEWAY_RUNNER" ]; then
    echo "[错误] 未找到 Gateway 启动器"
    echo "请重新下载完整的一键包"
    exit 1
fi

echo "[1/4] 环境检查..."
NODE_VERSION=$("$NODE_BIN" --version 2>/dev/null || true)
if [ -z "$NODE_VERSION" ]; then
    log "embedded Node.js failed to report version"
    echo "[错误] Node.js 运行时无法启动"
    exit 1
fi
log "embedded Node.js version $NODE_VERSION"
echo "  OK Node.js $NODE_VERSION"

# ── [2/4] 启动配置服务 ──
echo "[2/4] 启动配置服务..."
if [ -f "$CONFIG_WIZARD" ]; then
    log "starting config-server.mjs on port $WIZARD_PORT (always-on)"
    "$NODE_BIN" "$CONFIG_WIZARD" --port "$WIZARD_PORT" --gateway-port "$GATEWAY_PORT" >"$LOGS_DIR/config-wizard.log" 2>&1 &
    WIZARD_PID=$!

    # 等待配置服务就绪
    WIZ_WAIT=0
    while [ "$WIZ_WAIT" -lt 20 ]; do
        sleep 0.5
        WIZ_WAIT=$((WIZ_WAIT + 1))
        if curl -s -o /dev/null "http://127.0.0.1:$WIZARD_PORT/api/status" 2>/dev/null; then
            break
        fi
    done

    if curl -s -o /dev/null "http://127.0.0.1:$WIZARD_PORT/api/status" 2>/dev/null; then
        log "config wizard ready on port $WIZARD_PORT"
        echo "  OK 配置服务已启动 http://127.0.0.1:$WIZARD_PORT"
    else
        log "config wizard failed to start after $WIZ_WAIT attempts"
        echo "  [警告] 配置向导启动失败，继续启动 Gateway..."
    fi
else
    log "config-wizard not found, skipping"
    echo "  [警告] 未找到配置向导文件"
fi

# ── 检测是否需要弹出向导界面 ──
NEED_WIZARD=1
if [ -f "$CONFIG_FILE" ]; then
    # Check for skipWizard flag or env section
    HAS_CONFIG=$("$NODE_BIN" -e "
        try {
            const c = JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));
            if (c.gateway?.skipWizard === true) { process.stdout.write('ok'); process.exit(0); }
            const e = c.env;
            if (e && Object.keys(e).length > 0) { process.stdout.write('ok'); process.exit(0); }
        } catch {}
        process.stdout.write('no');
    " 2>/dev/null || echo "no")
    if [ "$HAS_CONFIG" = "ok" ]; then
        NEED_WIZARD=0
        log "config has env section or skipWizard, provider configured"
    else
        log "config missing env section, will open wizard"
    fi
else
    log "config file not found, will open wizard"
fi

if [ "$NEED_WIZARD" -eq 0 ]; then
    log "config ready, skipping wizard"
else
    # 弹出向导让用户配置
    if [ -f "$CONFIG_WIZARD" ]; then
        WIZARD_URL="http://127.0.0.1:$WIZARD_PORT"
        echo ""
        echo "  检测到尚未配置 AI 服务商，正在打开配置向导..."
        echo "  $WIZARD_URL"
        open "$WIZARD_URL"
        echo ""
        echo "  请在浏览器中完成配置，完成后此窗口将自动继续..."
        echo ""

        # 等待配置完成（轮询 env+model 均就绪，或用户选择跳过）
        while true; do
            sleep 2
            [ ! -f "$CONFIG_FILE" ] && continue
            CONFIG_READY=$("$NODE_BIN" -e "
                try {
                    const c = JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));
                    if (c.gateway?.skipWizard === true) { process.stdout.write('ok'); process.exit(0); }
                    const e = c.env;
                    const m = c.agents?.defaults?.model?.primary;
                    if (e && Object.keys(e).length > 0 && m) { process.stdout.write('ok'); process.exit(0); }
                } catch {}
                process.stdout.write('no');
            " 2>/dev/null || echo "no")
            if [ "$CONFIG_READY" = "ok" ]; then
                break
            fi
        done
        log "config wizard completed"
        echo "  OK 配置完成!"
    else
        echo "[错误] 未配置 AI 服务商，且配置向导不可用"
        exit 1
    fi
fi

log "config ready at $CONFIG_FILE"

# ── [3/4] 启动 OpenClaw ──
echo "[3/4] 启动 OpenClaw..."
[ -f "$GATEWAY_LOG" ] && : > "$GATEWAY_LOG"
log "launching gateway-runner.sh in background"
chmod +x "$GATEWAY_RUNNER"
bash "$GATEWAY_RUNNER" &
GATEWAY_PID=$!

WAIT_COUNT=0
while [ "$WAIT_COUNT" -lt 30 ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    log "waiting for gateway health, attempt $WAIT_COUNT"
    if curl -s -o /dev/null "http://127.0.0.1:$GATEWAY_PORT" 2>/dev/null; then
        log "gateway became healthy on port $GATEWAY_PORT"
        break
    fi
done

if ! curl -s -o /dev/null "http://127.0.0.1:$GATEWAY_PORT" 2>/dev/null; then
    log "gateway health check timed out after $WAIT_COUNT attempts"
    echo "[错误] 启动超时，请查看 logs/gateway.log"
    if [ -f "$GATEWAY_LOG" ]; then
        echo ""
        echo "===== logs/gateway.log 最近内容 ====="
        tail -20 "$GATEWAY_LOG"
        echo "===== 结束 ====="
    fi
    echo ""
    echo "启动失败。请运行 diagnose.sh 获取诊断信息。"
    kill "$GATEWAY_PID" 2>/dev/null || true
    exit 1
fi

# ── [4/4] 打开工作台 ──
echo ""
echo "[4/4] 打开工作台..."
echo "OK OpenClaw 已启动"

# 从配置文件读取网关令牌
GATEWAY_TOKEN=$("$NODE_BIN" -e "
    try {
        const c = JSON.parse(require('fs').readFileSync('$CONFIG_FILE','utf8'));
        if (c.gateway?.auth?.token) process.stdout.write(c.gateway.auth.token);
    } catch {}
" 2>/dev/null || true)

DASHBOARD_URL="http://127.0.0.1:$GATEWAY_PORT"
if [ -n "$GATEWAY_TOKEN" ]; then
    DASHBOARD_URL="http://127.0.0.1:$GATEWAY_PORT/#token=$GATEWAY_TOKEN"
    log "opening browser with token"
else
    log "opening browser without token"
fi

echo "正在打开浏览器: $DASHBOARD_URL"
open "$DASHBOARD_URL"
echo ""
echo "关闭此窗口将停止当前会话。"
echo "随时访问 http://127.0.0.1:$WIZARD_PORT 修改 AI 服务商配置"
echo "遇到问题请运行 diagnose.sh"
echo ""

# Keep alive until gateway exits
wait "$GATEWAY_PID" 2>/dev/null || true

# Cleanup wizard process
kill "$WIZARD_PID" 2>/dev/null || true
