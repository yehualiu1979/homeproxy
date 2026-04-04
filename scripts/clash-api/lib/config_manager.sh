#!/bin/bash
# 配置管理模块

# 读取用户配置
read_user_config() {
    echo "请输入 Clash API 配置信息："

    read -p "是否启用 Clash API? (y/N): " -n 1 -r
    echo
    CLASH_API_ENABLED=$([[ $REPLY =~ ^[Yy]$ ]] && echo "1" || echo "0")

    if [ "${CLASH_API_ENABLED}" == "1" ]; then
        read -p "外部控制器地址 [${CLASH_API_CONTROLLER}]: " input
        CLASH_API_CONTROLLER="${input:-${CLASH_API_CONTROLLER}}"

        read -p "WebUI 路径 [${CLASH_API_UI}]: " input
        CLASH_API_UI="${input:-${CLASH_API_UI}}"

        read -p "UI 下载使用的节点 (留空使用默认): " input
        CLASH_API_UI_DETOUR="${input}"

        read -p "默认模式 [${CLASH_API_DEFAULT_MODE}] (rule/direct/global): " input
        CLASH_API_DEFAULT_MODE="${input:-${CLASH_API_DEFAULT_MODE}}"

        read -sp "访问密码 (留空不设置): " input
        echo
        CLASH_API_SECRET="${input}"
    fi
}

# 生成 UCI 配置
generate_uci_config() {
    cat <<EOF
config homeproxy 'clash_api'
    option enabled '${CLASH_API_ENABLED}'
    option external_controller '${CLASH_API_CONTROLLER}'
    option external_ui '${CLASH_API_UI}'
    option external_ui_download_detour '${CLASH_API_UI_DETOUR}'
    option default_mode '${CLASH_API_DEFAULT_MODE}'
    option secret '${CLASH_API_SECRET}'
EOF
}

# 应用 UCI 配置
apply_uci_config() {
    local temp_config=$(mktemp)

    generate_uci_config > "${temp_config}"

    # 检查是否已存在 clash_api 配置
    if grep -q "^config homeproxy 'clash_api'" "${UCI_CONFIG}"; then
        log_info "更新现有 Clash API 配置"
        # 删除旧配置
        sed -i "/^config homeproxy 'clash_api'/,/^$/d" "${UCI_CONFIG}"
    fi

    # 添加新配置
    cat "${temp_config}" >> "${UCI_CONFIG}"

    rm -f "${temp_config}"

    log_info "UCI 配置已应用"
}

# 验证 UCI 配置
validate_uci_config() {
    # 检查配置格式
    if ! uci validate homeproxy 2>/dev/null; then
        log_error "UCI 配置验证失败"
        return 1
    fi

    log_info "UCI 配置验证通过"
    return 0
}