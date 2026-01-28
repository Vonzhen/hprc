cat > /etc/hprc/hprc.sh << 'EOF'
#!/bin/sh

# ==============================================================================
# HPRC - HomeProxy Ruleset Controller
# 主控菜单脚本
# ==============================================================================

# 引入核心模块
source /etc/hprc/modules/utils.sh
source /etc/hprc/modules/core_update.sh
source /etc/hprc/modules/core_system.sh
[ -f "/etc/hprc/config.conf" ] && source /etc/hprc/config.conf

# 捕获 Ctrl+C 信号，优雅退出
trap 'echo -e "\n操作已取消。"; exit 0' INT

# ==============================================================================
# 自动运行模式
# ==============================================================================
if [ "$1" = "auto" ]; then
    log_info "执行自动更新任务..."
    check_updates
    status=$?
    count=$(cat /tmp/hprc_update_count 2>/dev/null)
    
    if [ "$status" -eq 0 ] && [ "$count" -gt 0 ]; then
        log_info "发现变更，正在静默更新..."
        apply_updates
    else
        log_info "无更新，任务结束。"
    fi
    exit 0
fi

# ==============================================================================
# 交互式界面
# ==============================================================================

show_header() {
    clear
    echo -e "${BLUE}================================================================${NC}"
    echo -e "           ${YELLOW}HPRC${NC} - HomeProxy 规则集管理工具 ${BLUE}v1.1${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo -e "位置: ${TG_LOCATION_TAG:-未设置} | TG: $([ "$TG_ENABLE" = "1" ] && echo "${GREEN}ON${NC}" || echo "${RED}OFF${NC}") | Proxy: $([ -n "$GITHUB_PROXY" ] && echo "${YELLOW}ON${NC}" || echo "OFF")"
    print_line
}

action_check() {
    show_header
    check_updates
    local status=$?
    local count=$(cat /tmp/hprc_update_count 2>/dev/null)

    if [ "$status" -eq 0 ] && [ "$count" -gt 0 ]; then
        echo ""
        log_info "发现 $count 个变更。"
        read -p "是否立即应用更新并重启服务? [y/N] " confirm
        case "$confirm" in
            [yY][eE][sS]|[yY]) action_apply ;;
            *) log_info "已取消。"; read -p "按回车返回..." dummy ;;
        esac
    else
        echo ""
        read -p "按回车返回..." dummy
    fi
}

action_apply() {
    echo ""
    apply_updates
    echo ""
    read -p "按回车返回..." dummy
}

# 主循环
while true; do
    show_header
    echo -e " 1. ${GREEN}检测规则更新${NC}"
    echo -e " 2. ${YELLOW}强制应用更新${NC}"
    echo -e " 3. 修改系统配置 (Token/位置/代理)"
    echo -e " 4. 编辑规则列表 (Vim)"
    echo -e " 5. ${BLUE}更新脚本自身${NC}"
    echo -e " 0. 退出"
    print_line
    read -p "请输入选项 [0-5]: " choice

    case "$choice" in
        1) action_check ;;
        2) action_apply ;;
        3) configure_env ;;
        4) 
           if command -v vim >/dev/null; then EDITOR="vim"; else EDITOR="vi"; fi
           $EDITOR /etc/hprc/rules.list 
           ;;
        5) update_hprc ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
done
EOF
