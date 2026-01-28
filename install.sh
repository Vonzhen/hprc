#!/bin/sh

# ==============================================================================
# HPRC - HomeProxy Ruleset Controller 一键安装脚本
# ==============================================================================

# --- [Fork 用户请修改这里] ---
# 将下面的用户名改为你的 GitHub 用户名，即可从你的仓库安装
GITHUB_USER="Vonzhen" 
# ---------------------------

REPO_NAME="hprc"
BRANCH="master"
REPO_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"

INSTALL_DIR="/etc/hprc"
BIN_LINK="/usr/bin/hprc"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==========================================================${NC}"
echo -e "           ${GREEN}HPRC 自动安装程序${NC} (From: ${GITHUB_USER})"
echo -e "${BLUE}==========================================================${NC}"

# 1. 检查依赖
echo -e "-> 检查系统依赖..."
for cmd in wget tar md5sum; do
    if ! command -v "$cmd" > /dev/null; then
        echo -e "${RED}错误: 未找到 $cmd 命令，请先安装 (opkg install $cmd)。${NC}"
        exit 1
    fi
done

# 2. 交互式配置 (已调整：自动处理括号)
echo -e "-> 开始配置 (直接回车可跳过选填项)..."
read -p "请输入 Telegram Bot Token: " TG_BOT_TOKEN
read -p "请输入 Telegram Chat ID: " TG_CHAT_ID

TG_ENABLE=0
if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    TG_ENABLE=1
    # 修改点：提示用户直接输入名称，脚本自动加括号
    read -p "请输入位置名称 (无需输入括号，例如: 家): " LOCATION_INPUT
    
    # 如果用户没填，默认设为 OpenWrt
    if [ -z "$LOCATION_INPUT" ]; then
        LOCATION_INPUT="OpenWrt"
    fi
    
    # 自动拼接括号
    TG_LOCATION_TAG="【${LOCATION_INPUT}】"
else
    echo -e "${BLUE}提示: 未提供完整 TG 信息，通知功能将默认关闭。${NC}"
    TG_LOCATION_TAG="【OpenWrt】"
fi

# 3. 准备目录
mkdir -p "${INSTALL_DIR}/modules"
mkdir -p "${INSTALL_DIR}/temp"
mkdir -p "${INSTALL_DIR}/backup"

# 4. 生成配置文件
cat > "${INSTALL_DIR}/config.conf" <<EOF
# HPRC 配置文件
TG_ENABLE=${TG_ENABLE}
TG_BOT_TOKEN="${TG_BOT_TOKEN}"
TG_CHAT_ID="${TG_CHAT_ID}"
TG_LOCATION_TAG="${TG_LOCATION_TAG}"
HOMEPROXY_DIR="/etc/homeproxy"
RULESET_DIR="/etc/homeproxy/ruleset"
BACKUP_DIR="/etc/hprc/backup"
EOF

# 5. 从 GitHub 拉取文件
echo -e "-> 正在从 ${GITHUB_USER} 的仓库拉取核心文件..."

download_file() {
    local remote_path="$1"
    local local_path="$2"
    # 重试3次以应对网络波动
    wget -q --no-check-certificate -t 3 -O "$local_path" "${REPO_URL}/${remote_path}"
    if [ $? -ne 0 ] || [ ! -s "$local_path" ]; then
        echo -e "${RED}下载失败或文件为空: ${remote_path}${NC}"
        echo -e "请检查 GitHub 用户名是否正确，或仓库是否为 Public。"
        exit 1
    else
        echo -e "  - 已下载: ${remote_path}"
    fi
}

download_file "hprc.sh" "${INSTALL_DIR}/hprc.sh"
download_file "rules.list" "${INSTALL_DIR}/rules.list"
download_file "modules/utils.sh" "${INSTALL_DIR}/modules/utils.sh"
download_file "modules/core_update.sh" "${INSTALL_DIR}/modules/core_update.sh"
download_file "modules/core_notify.sh" "${INSTALL_DIR}/modules/core_notify.sh"

# 6. 完成安装
chmod -R 755 "${INSTALL_DIR}"
ln -sf "${INSTALL_DIR}/hprc.sh" "${BIN_LINK}"

echo -e "${BLUE}==========================================================${NC}"
echo -e "${GREEN}安装成功！${NC}"
echo -e "请在终端输入 ${GREEN}hprc${NC} 启动管理面板。"
echo -e "${BLUE}==========================================================${NC}"
