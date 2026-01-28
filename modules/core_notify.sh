#!/bin/sh

# 引入配置 (如果有)
[ -f "/etc/hprc/config.conf" ] && source /etc/hprc/config.conf
source /etc/hprc/modules/utils.sh

# 发送 Telegram 消息
# 用法: send_tg_message "消息内容"
send_tg_message() {
    local msg_content="$1"
    
    # 检查开关
    if [ "$TG_ENABLE" != "1" ]; then
        return 0
    fi

    if [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
        log_warn "TG通知未配置，跳过发送。"
        return 1
    fi

    # 组合消息：加入位置标签
    local full_msg="${TG_LOCATION_TAG} ${msg_content}"
    
    # URL 编码处理 (简单的 sed 替换)
    local encoded_msg=$(echo "$full_msg" | sed 's/ /%20/g' | sed ':a;N;$!ba;s/\n/%0A/g')

    # 发送请求 (静默模式，超时10秒，重试3次)
    if command -v curl > /dev/null; then
        curl -s -k -4 --retry 3 --connect-timeout 10 \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage?chat_id=${TG_CHAT_ID}&text=${encoded_msg}" > /dev/null
    else
        log_error "未找到 curl 命令，无法发送通知"
    fi
}
