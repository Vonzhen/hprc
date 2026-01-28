#!/bin/sh

source /etc/hprc/modules/utils.sh
source /etc/hprc/modules/core_notify.sh
[ -f "/etc/hprc/config.conf" ] && source /etc/hprc/config.conf

# 默认变量 (如果配置文件没定义)
TEMP_DIR="/etc/hprc/temp"
LIVE_DIR="${RULESET_DIR:-/etc/homeproxy/ruleset}"
BACKUP_DIR="${BACKUP_DIR:-/etc/hprc/backup}"
RULES_FILE="/etc/hprc/rules.list"
MIN_SIZE=10

# 清理并创建临时目录
cleanup_temp() {
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
}

# --- 功能 1: 检查更新 (只下载到 temp，不覆盖) ---
check_updates() {
    log_info "正在从 GitHub 获取最新规则..."
    cleanup_temp
    
    local update_count=0
    local change_log=""

    # 简单的表头
    printf "%-30s | %-10s | %-10s\n" "规则名称" "状态" "判定"
    print_line

    while IFS='|' read -r filename url || [ -n "$filename" ]; do
        if [ -z "$filename" ] || echo "$filename" | grep -q "^#"; then continue; fi
        
        temp_file="$TEMP_DIR/$filename"
        live_file="$LIVE_DIR/$filename"
        
        # 下载
        if ! wget -q -T 15 -t 2 -O "$temp_file" "$url" --no-check-certificate; then
             printf "%-30s | %-10s | ${RED}%-10s${NC}\n" "$filename" "下载失败" "跳过"
             continue
        fi

        # 大小检查
        if [ "$(wc -c < "$temp_file")" -lt "$MIN_SIZE" ]; then
             rm -f "$temp_file"
             continue
        fi

        # MD5 对比
        new_md5=$(md5sum "$temp_file" | awk '{print $1}')
        if [ -f "$live_file" ]; then
            old_md5=$(md5sum "$live_file" | awk '{print $1}')
            if [ "$new_md5" != "$old_md5" ]; then
                printf "%-30s | %-10s | ${YELLOW}%-10s${NC}\n" "$filename" "MD5不同" "需更新"
                update_count=$((update_count + 1))
                change_log="${change_log}%0A- ${filename} (更新)"
            else
                printf "%-30s | %-10s | ${GREEN}%-10s${NC}\n" "$filename" "一致" "无变化"
                rm -f "$temp_file" # 无需更新则删除临时文件
            fi
        else
            printf "%-30s | %-10s | ${BLUE}%-10s${NC}\n" "$filename" "不存在" "新增"
            update_count=$((update_count + 1))
            change_log="${change_log}%0A- ${filename} (新增)"
        fi
    done < "$RULES_FILE"
    
    print_line
    
    # 将结果写入临时状态文件，供主程序读取
    echo "$update_count" > /tmp/hprc_update_count
    echo "$change_log" > /tmp/hprc_change_log
    
    if [ "$update_count" -gt 0 ]; then
        log_info "检测到 $update_count 个规则需要更新。"
        return 0
    else
        log_success "所有规则已是最新。"
        return 1
    fi
}

# --- 功能 2: 应用更新 (备份 -> 移动 -> 重启 -> 回滚) ---
apply_updates() {
    log_info "开始应用更新..."
    
    # 1. 备份
    log_info "备份当前规则到 $BACKUP_DIR..."
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp -a "$LIVE_DIR"/* "$BACKUP_DIR"/ 2>/dev/null
    
    # 2. 覆盖 (将 temp 中剩余的文件移动过去)
    log_info "覆盖新规则..."
    # 确保目标目录存在
    mkdir -p "$LIVE_DIR"
    # 仅移动 temp 中存在的文件（这些是 MD5 变动过的）
    if [ "$(ls -A $TEMP_DIR)" ]; then
        cp -f "$TEMP_DIR"/* "$LIVE_DIR"/
    else
        log_warn "临时目录为空，没有文件需要覆盖。"
        return 0
    fi
    
    # 3. 重启服务
    log_info "重启 HomeProxy 服务..."
    /etc/init.d/homeproxy restart
    sleep 5
    
    # 4. 状态检测与回滚
    if /etc/init.d/homeproxy running; then
        log_success "HomeProxy 启动成功，更新完成！"
        
        # 发送成功通知
        change_log=$(cat /tmp/hprc_change_log 2>/dev/null)
        send_tg_message "✅ 规则更新成功！${change_log}"
        
        # 清理
        rm -rf "$TEMP_DIR"
    else
        log_error "HomeProxy 启动失败！正在回滚..."
        send_tg_message "⚠️ 规则更新导致服务启动失败，正在回滚..."
        
        # 回滚操作
        rm -rf "$LIVE_DIR"/*
        cp -a "$BACKUP_DIR"/* "$LIVE_DIR"/
        /etc/init.d/homeproxy restart
        
        if /etc/init.d/homeproxy running; then
            log_success "已回滚到旧版本，服务恢复正常。"
            send_tg_message "🚫 已回滚到旧版本，服务已恢复。"
        else
            log_error "致命错误：回滚后服务仍无法启动，请手动检查！"
            send_tg_message "❌ 致命错误：回滚失败，请手动干预！"
        fi
    fi
}
