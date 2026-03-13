#!/bin/bash
# ============================================================
# ClawStart macOS 启动器
# 下载即运行，开箱就能用
# ============================================================

set -e

CLAWSTART_HOME="$(cd "$(dirname "$0")" && pwd)"
NODE_BIN="$CLAWSTART_HOME/runtime/node/bin/node"
OPENCLAW_BIN="$CLAWSTART_HOME/openclaw/bin/openclaw"
CONFIG_DIR="$CLAWSTART_HOME/config"
FIRST_RUN_FLAG="$CONFIG_DIR/.initialized"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}  🦞 ClawStart - OpenClaw 免安装部署站${NC}"
    echo -e "  下载即运行，开箱就能用"
    echo ""
}

check_env() {
    echo -e "  ${BOLD}环境检测${NC}"

    # 检查 Node.js
    if [ -x "$NODE_BIN" ]; then
        local ver=$("$NODE_BIN" --version 2>/dev/null)
        echo -e "  ✓ Node.js $ver"
    else
        echo -e "  ${RED}✗ 未找到内嵌 Node.js${NC}"
        echo -e "  ${YELLOW}请重新下载完整的 ClawStart 一键包${NC}"
        exit 1
    fi

    # 检查 OpenClaw
    if [ -f "$OPENCLAW_BIN" ]; then
        echo -e "  ✓ OpenClaw 已就绪"
    else
        echo -e "  ${RED}✗ 未找到 OpenClaw${NC}"
        exit 1
    fi

    # 检查端口
    if lsof -i :3000 >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ 端口 3000 已被占用${NC}"
        echo -e "  ${YELLOW}  尝试使用备用端口 3001...${NC}"
        export OPENCLAW_PORT=3001
    else
        echo -e "  ✓ 端口 3000 可用"
        export OPENCLAW_PORT=3000
    fi

    # 磁盘空间
    local free_mb=$(df -m "$CLAWSTART_HOME" | awk 'NR==2{print $4}')
    if [ "$free_mb" -lt 500 ]; then
        echo -e "  ${YELLOW}⚠ 磁盘空间不足 500MB (${free_mb}MB)${NC}"
    else
        echo -e "  ✓ 磁盘空间充足 (${free_mb}MB)"
    fi

    echo ""
}

first_run() {
    if [ -f "$FIRST_RUN_FLAG" ]; then
        return
    fi

    echo -e "  ${GREEN}🎉 欢迎使用 ClawStart！${NC}"
    echo -e "  首次运行，需要配置 AI 模型"
    echo ""
    echo -e "  请选择模型供应商："
    echo -e "    ${BOLD}1${NC}) 火山引擎 (豆包)"
    echo -e "    ${BOLD}2${NC}) 硅基流动 (SiliconFlow)"
    echo -e "    ${BOLD}3${NC}) DeepSeek"
    echo -e "    ${BOLD}4${NC}) 自定义 (OpenAI 兼容)"
    echo ""
    read -p "  请输入选项 [1-4]: " choice

    local provider=""
    local api_base=""
    local model_id=""

    case $choice in
        1)
            provider="volcengine"
            api_base="https://ark.cn-beijing.volces.com/api/v3"
            model_id="doubao-seed-2-0-lite"
            ;;
        2)
            provider="siliconflow"
            api_base="https://api.siliconflow.cn/v1"
            model_id="deepseek-ai/DeepSeek-V3"
            ;;
        3)
            provider="deepseek"
            api_base="https://api.deepseek.com/v1"
            model_id="deepseek-chat"
            ;;
        4)
            provider="custom"
            read -p "  API 地址: " api_base
            read -p "  模型 ID: " model_id
            ;;
        *)
            echo -e "  ${YELLOW}无效选项，使用默认 DeepSeek${NC}"
            provider="deepseek"
            api_base="https://api.deepseek.com/v1"
            model_id="deepseek-chat"
            ;;
    esac

    echo ""
    read -p "  请输入 API Key: " api_key

    if [ -z "$api_key" ]; then
        echo -e "  ${RED}API Key 不能为空${NC}"
        exit 1
    fi

    # 测试连通性
    echo -e "  测试 API 连通性..."
    local test_result=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d '{"model":"'"$model_id"'","messages":[{"role":"user","content":"hi"}],"max_tokens":5}' \
        "$api_base/chat/completions" 2>/dev/null)

    if [ "$test_result" = "200" ]; then
        echo -e "  ${GREEN}✓ API 连接成功！${NC}"
    else
        echo -e "  ${YELLOW}⚠ API 返回 $test_result，可能需要检查 Key 或网络${NC}"
        read -p "  是否继续？(y/n): " cont
        if [ "$cont" != "y" ]; then
            exit 1
        fi
    fi

    # 保存配置
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/provider.json" << EOF
{
  "provider": "$provider",
  "apiBase": "$api_base",
  "modelId": "$model_id",
  "apiKey": "$api_key"
}
EOF

    touch "$FIRST_RUN_FLAG"
    echo -e "  ${GREEN}✓ 配置完成！${NC}"
    echo ""
}

start_openclaw() {
    echo -e "  ${BOLD}启动 OpenClaw...${NC}"

    export PATH="$CLAWSTART_HOME/runtime/node/bin:$PATH"
    export OPENCLAW_HOME="$CLAWSTART_HOME/openclaw"

    "$OPENCLAW_BIN" gateway start --port "$OPENCLAW_PORT" &
    local pid=$!

    # 等待服务就绪
    local retries=0
    while [ $retries -lt 30 ]; do
        if curl -s "http://localhost:$OPENCLAW_PORT" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ OpenClaw 已启动 (端口 $OPENCLAW_PORT)${NC}"
            echo ""
            echo -e "  ${CYAN}正在打开浏览器...${NC}"
            open "http://localhost:$OPENCLAW_PORT"
            echo ""
            echo -e "  ${GREEN}🦞 一切就绪！享受你的 AI 管家吧${NC}"
            echo -e "  按 Ctrl+C 停止服务"
            echo ""
            wait $pid
            return
        fi
        sleep 1
        retries=$((retries + 1))
    done

    echo -e "  ${RED}✗ 启动超时，请检查日志${NC}"
    echo -e "  运行 ${CYAN}./diagnose.sh${NC} 获取诊断报告"
    kill $pid 2>/dev/null
    exit 1
}

# 主流程
banner
check_env
first_run
start_openclaw
