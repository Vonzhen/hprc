#!/bin/sh

source /etc/hprc/modules/utils.sh
[ -f "/etc/hprc/config.conf" ] && source /etc/hprc/config.conf

# 默认设置
GITHUB_USER="Vonzhen"
REPO_NAME="hprc"
BRANCH="master"
# 更新脚本自身时，默认使用 Raw 源 (因为此时代理通常是正常的)
# 如果需要，也可以读取配置中的 GITHUB_PROXY
BASE_URL="${GITHUB_PROXY}https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}"

# --- 功能 1: 更新脚本自身 ---
update_hprc() {
    log_info "正在检查脚本更新..."
    log_info "源地址: $BASE_URL"
    
    TEMP_UPDATE_DIR="/tmp/hprc_update"
    rm -rf "$TEMP_UPDATE_DIR"
    mkdir -p "$TEMP_UPDATE_DIR/modules"

    # 定义要更新的文件列表 (注意：config.conf 不更新，保护用户配置)
    files="hprc.sh rules.list modules/utils.sh modules/core_update.sh modules/core_notify.sh modules/core_system.sh"

    error_flag=0

    for file in $files; do
        local url="${BASE_URL}/${file}"
        local dest="${TEMP_UPDATE_DIR}/${file}"
        
        # 这里的 wget 使用 config 中可能定义的代理前缀
        wget -q --no-check-certificate -t 3 -T 10 -O "$dest" "$url"
        
        if [ $? -eq 0 ] && [ -s "$dest" ]; then
            echo -e "下载 $file ... ${GREEN}[OK]${NC}"
        else
            echo -e "下载 $file ... ${RED}[失败]${NC}"
            error_flag=1
        fi
    done

    if [ "$error_flag" -eq 1 ]; then
        log_error "部分文件下载失败，取消更新，原文件未变动。"
        rm -rf "$TEMP_UPDATE_DIR"
        return 1
    fi

    log_info "下载完成，开始覆盖..."
    
    # 覆盖文件
    cp -f "$TEMP_UPDATE_DIR/hprc.sh" "/etc/hprc/hprc.sh"
    cp -f "$TEMP_UPDATE_DIR/rules.list" "/etc/hprc/rules.list"
    cp -f "$TEMP_UPDATE_DIR/modules/"* "/etc/hprc/modules/"
    
    # 重新赋予权限
    chmod +x /etc/hprc/hprc.sh
    chmod +x /etc/hprc/modules/*.sh
    
    # 清理
    rm -rf "$TEMP_UPDATE_DIR"
    
    log_success "HPRC 更新成功！请重新运行脚本以加载新代码。"
    sleep 2
    exit 0
}

# --- 功能 2: 交互式修改配置 ---
configure_env() {
    echo -e "${BLUE}=== 修改配置 (直接回车保持原值) ===${NC}"
    
    # 读取当前配置
    [ -f "/etc/hprc/config.conf" ] && source /etc/hprc/config.conf
    
    # 1. 设置 TG Token
    echo -e "\n当前 Bot Token: ${YELLOW}${TG_BOT_TOKEN:-未设置}${NC}"
    read -p "请输入新 Token: " input_token
    new_token="${input_token:-$TG_BOT_TOKEN}"
    
    # 2. 设置 Chat ID
    echo -e "\n当前 Chat ID: ${YELLOW}${TG_CHAT_ID:-未设置}${NC}"
    read -p "请输入新 Chat ID: " input_chatid
    new_chatid="${input_chatid:-$TG_CHAT_ID}"
    
    # 3. 设置位置标签
    echo -e "\n当前位置标签: ${YELLOW}${TG_LOCATION_TAG:-未设置}${NC}"
    read -p "请输入新位置 (如 '公司', 脚本会自动加括号): " input_loc
    if [ -n "$input_loc" ]; then
        new_loc="【${input_loc}】"
    else
        new_loc="$TG_LOCATION_TAG"
    fi
    
    # 4. 设置 GitHub 代理前缀 (新增功能)
    echo -e "\n当前下载代理: ${YELLOW}${GITHUB_PROXY:-直连}${NC}"
    echo -e "提示: 如果下载困难，可填镜像地址 (如 https://ghproxy.com/)"
    read -p "请输入代理前缀 (输入 'clear' 清空): " input_proxy
    
    if [ "$input_proxy" = "clear" ]; then
        new_proxy=""
    else
        new_proxy="${input_proxy:-$GITHUB_PROXY}"
    fi

    # 自动开关 TG
    if [ -n "$new_token" ] && [ -n "$new_chatid" ]; then
        new_enable=1
    else
        new_enable=0
    fi
    
    # 5. 写入文件 (保留原有路径配置)
    cat > "/etc/hprc/config.conf" <<EOF
# HPRC 配置文件
# 更新时间: $(date)
TG_ENABLE=${new_enable}
TG_BOT_TOKEN="${new_token}"
TG_CHAT_ID="${new_chatid}"
TG_LOCATION_TAG="${new_loc}"
GITHUB_PROXY="${new_proxy}"

HOMEPROXY_DIR="${HOMEPROXY_DIR:-/etc/homeproxy}"
RULESET_DIR="${RULESET_DIR:-/etc/homeproxy/ruleset}"
BACKUP_DIR="${BACKUP_DIR:-/etc/hprc/backup}"
EOF

    log_success "配置已更新！"
    sleep 1
}
