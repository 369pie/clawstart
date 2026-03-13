#!/bin/bash
# ============================================================
# ClawStart macOS 诊断工具
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
        RECOMMENDED_ACTION="重新运行 launch.command，完成首次配置。"
        return
    fi

    [ -f "$PRIMARY_LOG" ] && detect_rule_from_file "$PRIMARY_LOG"
    [ "$MATCHED_RULE" = "NONE" ] && [ -f "$SECONDARY_LOG" ] && detect_rule_from_file "$SECONDARY_LOG"
}

detect_rule_from_file() {
    local log_file="$1"
    local content
    content="$(tr '[:upper:]' '[:lower:]' < "$log_file" 2>/dev/null)"

    if printf '%s' "$content" | grep -qE 'permission denied \(publickey\)|ssh://git@github|git@github\.com'; then
        ERROR_CODE="GIT_SSH_PERMISSION"
        MATCHED_RULE="R001"
        HUMAN_TITLE="Git SSH 权限错误"
        RECOMMENDED_ACTION="把 Git 拉取方式切到 HTTPS，再重新安装。"
        MANUAL_COMMAND='git config --global url."https://github.com/".insteadOf ssh://git@github.com/'
        return
    fi

    if printf '%s' "$content" | grep -qE 'exit 128|code 128'; then
        ERROR_CODE="GIT_EXIT_128"
        MATCHED_RULE="R002"
        HUMAN_TITLE="Git 操作异常"
        RECOMMENDED_ACTION="先确认 Git 可用，再切换到 HTTPS 模式。"
        MANUAL_COMMAND='git --version'
        return
    fi

    if printf '%s' "$content" | grep -qE 'cannot find native binding|native binding'; then
        ERROR_CODE="NATIVE_BINDING_MISSING"
        MATCHED_RULE="R003"
        HUMAN_TITLE="原生依赖缺失"
        RECOMMENDED_ACTION="重新安装底层 OpenClaw CLI。"
        MANUAL_COMMAND='npm i -g openclaw'
        return
    fi

    if printf '%s' "$content" | grep -qE 'eperm|operation not permitted'; then
        ERROR_CODE="FILE_PERMISSION_BLOCKED"
        MATCHED_RULE="R004"
        HUMAN_TITLE="文件被占用或权限不足"
        RECOMMENDED_ACTION="关闭旧进程、处理权限拦截后再重试。"
        return
    fi

    if printf '%s' "$content" | grep -qE 'enoent|-4058|cannot find module|module_not_found'; then
        ERROR_CODE="INSTALL_INCOMPLETE"
        MATCHED_RULE="R005_R007"
        HUMAN_TITLE="文件缺失或安装不完整"
        RECOMMENDED_ACTION="清理缓存后重装；一键包用户优先重新下载并解压到新目录。"
        MANUAL_COMMAND='npm cache clean --force'
        return
    fi

    if printf '%s' "$content" | grep -qE 'eacces|permission denied'; then
        ERROR_CODE="ACCESS_DENIED"
        MATCHED_RULE="R006"
        HUMAN_TITLE="安装权限不足"
        RECOMMENDED_ACTION="请在终端使用 sudo 或检查目录权限后重试。"
        MANUAL_COMMAND='sudo npm install -g openclaw'
        return
    fi

    if printf '%s' "$content" | grep -qE 'etimedout|econnrefused|enotfound|fetch failed|socket hang up|econnreset|unable to get local issuer'; then
        ERROR_CODE="NETWORK_UNREACHABLE"
        MATCHED_RULE="R008"
        HUMAN_TITLE="网络、代理或证书问题"
        RECOMMENDED_ACTION="先切换网络或关闭代理，再优先使用国内镜像重试。"
        MANUAL_COMMAND='npm config set strict-ssl false'
        return
    fi

    if printf '%s' "$content" | grep -qE 'integrity|sha512|cache'; then
        ERROR_CODE="NPM_CACHE_CORRUPTED"
        MATCHED_RULE="R009"
        HUMAN_TITLE="npm 缓存异常"
        RECOMMENDED_ACTION="清理 npm 缓存后重新安装。"
        MANUAL_COMMAND='npm cache clean --force'
        return
    fi

    if printf '%s' "$content" | grep -qE 'engine|unsupported|required:'; then
        ERROR_CODE="NODE_VERSION_UNSUPPORTED"
        MATCHED_RULE="R010"
        HUMAN_TITLE="Node.js 版本不兼容"
        RECOMMENDED_ACTION="先升级 Node.js 到当前要求版本以上，再重新执行安装。"
        return
    fi

    if printf '%s' "$content" | grep -qE 'cb\(\) never called|npm err|code 1'; then
        ERROR_CODE="NPM_RUNTIME_ERROR"
        MATCHED_RULE="R011"
        HUMAN_TITLE="npm 本身异常"
        RECOMMENDED_ACTION="先升级 npm，再重新安装底层 CLI。"
        MANUAL_COMMAND='npm install -g npm@latest'
        return
    fi

    if printf '%s' "$content" | grep -qE 'enospc|no space'; then
        ERROR_CODE="DISK_SPACE_LOW"
        MATCHED_RULE="R012"
        HUMAN_TITLE="磁盘空间不足"
        RECOMMENDED_ACTION="先清理磁盘空间，再重新安装或启动。"
        return
    fi
}

detect_rule

cat > "$REPORT" << 'HEADER'
==============================
 ClawStart 诊断报告
HEADER
echo " 生成时间: $(date)" >> "$REPORT"
echo "==============================" >> "$REPORT"
echo "" >> "$REPORT"

# 系统信息
echo "  [1/6] 系统信息..."
echo "--- 系统信息 ---" >> "$REPORT"
sw_vers >> "$REPORT" 2>/dev/null
uname -a >> "$REPORT"
sysctl -n hw.memsize 2>/dev/null | awk '{printf "内存: %.0f GB\n", $1/1073741824}' >> "$REPORT"
echo "" >> "$REPORT"

# 磁盘空间
echo "  [2/6] 磁盘空间..."
echo "--- 磁盘空间 ---" >> "$REPORT"
df -h "$CLAWSTART_HOME" >> "$REPORT"
echo "" >> "$REPORT"

# Node.js
echo "  [3/6] Node.js 环境..."
echo "--- Node.js ---" >> "$REPORT"
if [ -x "$CLAWSTART_HOME/runtime/node/bin/node" ]; then
    echo "内嵌 Node.js: $($CLAWSTART_HOME/runtime/node/bin/node --version)" >> "$REPORT"
else
    echo "内嵌 Node.js: 未找到" >> "$REPORT"
fi
which node >> "$REPORT" 2>/dev/null && node --version >> "$REPORT" 2>/dev/null || echo "系统 Node.js: 未安装" >> "$REPORT"
echo "" >> "$REPORT"

# 端口
echo "  [4/6] 端口占用..."
echo "--- 端口检测 ---" >> "$REPORT"
for port in 3000 3001 8080 8888; do
    if lsof -i :$port >/dev/null 2>&1; then
        echo "端口 $port: 占用" >> "$REPORT"
        lsof -i :$port | head -3 >> "$REPORT"
    else
        echo "端口 $port: 空闲" >> "$REPORT"
    fi
done
echo "" >> "$REPORT"

# 配置
echo "  [5/6] 配置文件..."
echo "--- 配置文件 ---" >> "$REPORT"
if [ -f "$CONFIG_FILE" ]; then
    echo "openclaw.json: 存在" >> "$REPORT"
    grep -E '"workspace"|"gateway"|"agents"' "$CONFIG_FILE" >> "$REPORT" || true
else
    echo "openclaw.json: 未配置" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 网络
echo "  [6/6] 网络连通性..."
echo "--- 网络测试 ---" >> "$REPORT"
if ping -c 1 -W 3 baidu.com >/dev/null 2>&1; then
    echo "基础网络: 正常" >> "$REPORT"
else
    echo "基础网络: 异常" >> "$REPORT"
fi
if curl -s --max-time 5 -o /dev/null https://api.deepseek.com 2>/dev/null; then
    echo "DeepSeek API: 可达" >> "$REPORT"
else
    echo "DeepSeek API: 不可达" >> "$REPORT"
fi
echo "" >> "$REPORT"

echo "--- 规则化诊断结论 ---" >> "$REPORT"
echo "error_code: $ERROR_CODE" >> "$REPORT"
echo "matched_rule: $MATCHED_RULE" >> "$REPORT"
echo "human_title: $HUMAN_TITLE" >> "$REPORT"
echo "recommended_action: $RECOMMENDED_ACTION" >> "$REPORT"
if [ -n "$MANUAL_COMMAND" ]; then
    echo "manual_command: $MANUAL_COMMAND" >> "$REPORT"
fi
echo "" >> "$REPORT"

echo "--- 日志来源 ---" >> "$REPORT"
[ -f "$PRIMARY_LOG" ] && echo "primary_log: $PRIMARY_LOG" >> "$REPORT" || echo "primary_log: NOT_FOUND" >> "$REPORT"
[ -f "$SECONDARY_LOG" ] && echo "secondary_log: $SECONDARY_LOG" >> "$REPORT" || echo "secondary_log: NOT_FOUND" >> "$REPORT"
echo "" >> "$REPORT"

echo "==============================" >> "$REPORT"
echo " 诊断完成" >> "$REPORT"
echo "==============================" >> "$REPORT"

echo ""
echo -e "${GREEN}  ✓ 诊断完成！${NC}"
echo ""
echo -e "  规则化结论: ${CYAN}${HUMAN_TITLE}${NC}"
echo -e "  建议动作: ${YELLOW}${RECOMMENDED_ACTION}${NC}"
if [ -n "$MANUAL_COMMAND" ]; then
    echo -e "  手动命令: ${CYAN}${MANUAL_COMMAND}${NC}"
fi
echo ""
echo "  报告已保存到: $REPORT"
echo ""
echo -e "${YELLOW}  如需帮助，请将 diagnostic.txt 发到社群：${NC}"
echo "    QQ群: [待填写]"
echo "    微信群: [待填写]"
echo ""
