#!/bin/bash
# ============================================================
# ClawStart Linux 诊断工具
# ============================================================

CLAWSTART_HOME="$(cd "$(dirname "$0")" && pwd)"
REPORT="$CLAWSTART_HOME/diagnostic.txt"
PRIMARY_LOG="$CLAWSTART_HOME/logs/gateway.log"
SECONDARY_LOG="$HOME/.openclaw/logs/gateway.log"
STATE_DIR="$CLAWSTART_HOME/state"
CONFIG_FILE="$STATE_DIR/openclaw.json"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERROR_CODE="OK"
MATCHED_RULE="NONE"
HUMAN_TITLE="未发现明确错误规则"
RECOMMENDED_ACTION="优先回到快速开始逐步检查；如仍失败，再把本报告发给支持人员。"
MANUAL_COMMAND=""

echo ""
echo -e "${CYAN}  ClawStart 诊断工具${NC}"
echo "  正在收集系统信息..."
echo ""

detect_rule() {
    if [ ! -x "$CLAWSTART_HOME/runtime/node/bin/node" ]; then
        ERROR_CODE="NODE_EMBEDDED_MISSING"
        MATCHED_RULE="ENV_NODE_MISSING"
        HUMAN_TITLE="未找到内嵌 Node.js 运行时"
        RECOMMENDED_ACTION="重新下载完整的一键包，不要只保留单个脚本或目录。"
        return
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        ERROR_CODE="CONFIG_OPENCLAW_MISSING"
        MATCHED_RULE="CFG_OPENCLAW_SETUP_MISSING"
        HUMAN_TITLE="还没有完成 OpenClaw 首次配置"
        RECOMMENDED_ACTION="重新运行 launch.sh，完成首次配置。"
        return
    fi

    [ -f "$PRIMARY_LOG" ] && detect_rule_from_file "$PRIMARY_LOG"
    [ "$MATCHED_RULE" = "NONE" ] && [ -f "$SECONDARY_LOG" ] && detect_rule_from_file "$SECONDARY_LOG"
}

detect_rule_from_file() {
    local logfile="$1"
    local last_lines
    last_lines=$(tail -100 "$logfile" 2>/dev/null || true)

    if echo "$last_lines" | grep -qi "EADDRINUSE"; then
        ERROR_CODE="GATEWAY_PORT_IN_USE"
        MATCHED_RULE="GW_EADDRINUSE"
        HUMAN_TITLE="网关端口被占用"
        RECOMMENDED_ACTION="关闭占用 18789 端口的进程，然后重新运行 launch.sh"
        MANUAL_COMMAND="lsof -ti :18789 | xargs kill -9"
        return
    fi

    if echo "$last_lines" | grep -qi "401\|Unauthorized\|未认证"; then
        ERROR_CODE="GATEWAY_AUTH_FAILED"
        MATCHED_RULE="GW_AUTH_FAIL"
        HUMAN_TITLE="网关认证失败"
        RECOMMENDED_ACTION="检查 state/openclaw.json 中的 gateway.auth.token 是否正确配置"
        return
    fi

    if echo "$last_lines" | grep -qi "ECONNREFUSED"; then
        ERROR_CODE="PROVIDER_UNREACHABLE"
        MATCHED_RULE="NET_PROVIDER_REFUSED"
        HUMAN_TITLE="无法连接到 AI 服务商"
        RECOMMENDED_ACTION="检查网络连接和代理设置，确认 API 地址可达"
        return
    fi
}

detect_rule

# Collect system info
{
    echo "===== ClawStart Linux Diagnostic Report ====="
    echo "Date: $(date)"
    echo "Platform: $(uname -srm)"
    echo "Distribution: $(cat /etc/os-release 2>/dev/null | head -5 || echo 'unknown')"
    echo ""
    echo "===== Error Detection ====="
    echo "ERROR_CODE: $ERROR_CODE"
    echo "MATCHED_RULE: $MATCHED_RULE"
    echo "TITLE: $HUMAN_TITLE"
    echo "ACTION: $RECOMMENDED_ACTION"
    [ -n "$MANUAL_COMMAND" ] && echo "MANUAL_CMD: $MANUAL_COMMAND"
    echo ""
    echo "===== Node.js ====="
    if [ -x "$CLAWSTART_HOME/runtime/node/bin/node" ]; then
        echo "Bundled: $("$CLAWSTART_HOME/runtime/node/bin/node" --version 2>/dev/null || echo 'error')"
    else
        echo "Bundled: NOT FOUND"
    fi
    echo "System: $(node --version 2>/dev/null || echo 'not installed')"
    echo ""
    echo "===== Config ====="
    if [ -f "$CONFIG_FILE" ]; then
        echo "Config exists: yes"
        echo "Config size: $(wc -c < "$CONFIG_FILE") bytes"
    else
        echo "Config exists: no"
    fi
    echo ""
    echo "===== Gateway Log (last 50 lines) ====="
    if [ -f "$PRIMARY_LOG" ]; then
        tail -50 "$PRIMARY_LOG"
    else
        echo "(no log file found)"
    fi
    echo ""
    echo "===== Config Wizard Log (last 20 lines) ====="
    if [ -f "$CLAWSTART_HOME/logs/config-wizard.log" ]; then
        tail -20 "$CLAWSTART_HOME/logs/config-wizard.log"
    else
        echo "(no log file found)"
    fi
    echo ""
    echo "===== Port Check ====="
    echo "18789: $(lsof -ti :18789 2>/dev/null || echo 'free')"
    echo "18790: $(lsof -ti :18790 2>/dev/null || echo 'free')"
    echo ""
    echo "===== Disk Space ====="
    df -h "$CLAWSTART_HOME" 2>/dev/null || echo "unable to check"
} > "$REPORT" 2>&1

echo -e "${GREEN}诊断结果:${NC}"
echo ""
echo -e "  错误代码: ${CYAN}$ERROR_CODE${NC}"
echo -e "  问题描述: $HUMAN_TITLE"
echo -e "  建议操作: $RECOMMENDED_ACTION"
[ -n "$MANUAL_COMMAND" ] && echo -e "  手动修复: ${YELLOW}$MANUAL_COMMAND${NC}"
echo ""
echo "完整报告已保存到: $REPORT"
echo ""
