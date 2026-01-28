#!/bin/sh

# ==============================================================================
# HPRC - HomeProxy Ruleset Controller
# 主控菜单脚本
# ==============================================================================

# 引入核心模块
source /etc/hprc/modules/utils.sh
source /etc/hprc/modules/core_update.sh
[ -f "/etc/hprc/config.conf" ] && source /etc/hprc/config.conf

# 捕获 Ctrl+C 信号，优雅退出
trap 'echo -e "\n操作已取消。"; exit 0' INT

# ==============================================================================
# 自动运行模式 (供 Crontab 定时任务调用)
# 用法: hprc auto
# ==============================================================================
if [ "$1" = "auto" ]; then
    log_info "执行自动更新任务..."
    
    # 执行检测
    check_updates
    status=$?
    count=$(cat /tmp/hprc_update_count 2>/dev/null)
    
    # 状态 0 且 变更数量 > 0 表示有更新
    if [ "$status" -eq 0 ] && [ "$count" -gt 0 ]; then
        log_info "发现变更，正在静默更新..."
        apply_updates
        # apply_updates 内部会处理重启服务和发送 TG 通知
    else
        log_info "无更新，任务结束。"
    fi
    exit 0
fi

# ==============================================================================
# 交互式界面逻辑
# ==============================================================================

# 标题显示函数
show_header() {
    clear
    echo -e "${BLUE}================================================================${NC}"
    echo -e "           ${YELLOW}HPRC${NC} - HomeProxy 规则集管理工具 ${BLUE}v1.0${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo -e "当前规则路径: ${RULESET_DIR:-/etc/homeproxy/ruleset}"
    print_line
}

# 菜单动作：检测更新
action_check() {
    show_header
    check_updates
    local status=$?
    local count=$(cat /tmp/hprc_update_count 2>/dev/null)

    # 状态 0 表示有更新 (Shell习惯: 0=Success/True)
    if [ "$status" -eq 0 ] && [ "$count" -gt 0 ]; then
        echo ""
        log_info "发现 $count 个变更。"
        read -p "是否立即应用更新并重启服务? [y/N] " confirm
        case "$confirm" in
            [yY][eE][sS]|[yY]) 
                action_apply ;;
            *) 
                log_info "已取消应用。临时文件保留在 $TEMP_DIR" 
                read -p "按回车键返回菜单..." dummy
                ;;
        esac
    else
        echo ""
        read -p "按回车键返回菜单..." dummy
    fi
}

# 菜单动作：强制更新
action_apply() {
    echo ""
    apply_updates
    echo ""
    read -p "按回车键返回菜单..." dummy
}

# 菜单动作：编辑规则
action_edit_rules() {
    if command -v vim >/dev/null; then EDITOR="vim"; else EDITOR="vi"; fi
    $EDITOR /etc/hprc/rules.list
}

# 菜单动作：编辑配置
action_edit_config() {
    if command -v vim >/dev/null; then EDITOR="vim"; else EDITOR="vi"; fi
    $EDITOR /etc/hprc/config.conf
}

# 主循环
while true; do
    show_header
    echo -e " 1. ${GREEN}检测更新${NC} (对比 MD5，暂不覆盖)"
    echo -e " 2. ${YELLOW}强制更新${NC} (直接覆盖并重启)"
    echo -e " 3. 编辑规则列表"
    echo -e " 4. 编辑配置文件"
    echo -e " 0. 退出"
    print_line
    read -p "请输入选项 [0-4]: " choice

    case "$choice" in
        1) action_check ;;
        2) action_apply ;;
        3) action_edit_rules ;;
        4) action_edit_config ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重试。${NC}"; sleep 1 ;;
    esac
done
