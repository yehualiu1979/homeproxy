#!/bin/bash
# Clash API 安装脚本
# 版本: 1.0.0

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置和函数库
source "${SCRIPT_DIR}/config/clash_api.conf"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/version_checker.sh"
source "${SCRIPT_DIR}/lib/config_manager.sh"
source "${SCRIPT_DIR}/lib/file_modifier.sh"

# 检查系统环境
check_environment() {
    local errors=0

    # 检查必需命令
    for cmd in ucode sed grep awk; do
        if ! command_exists "${cmd}"; then
            log_error "缺少必需命令: ${cmd}"
            errors=$((errors + 1))
        fi
    done

    # 检查文件
    for file in "${GENERATE_CLIENT_UC}" "${CLIENT_JS}" "${UCI_CONFIG}"; do
        if ! file_exists "${file}"; then
            log_error "文件不存在: ${file}"
            errors=$((errors + 1))
        fi
    done

    # 检查 sing-box 版本
    if ! check_singbox_version; then
        errors=$((errors + 1))
    fi

    return ${errors}
}

# 主函数
main() {
    log_info "=== Clash API 安装脚本开始 ==="
    log_info "脚本版本: 1.0.0"
    log_info "项目路径: ${PROJECT_ROOT}"

    # 1. 环境检查
    log_info "步骤 1: 环境检查..."
    if ! check_environment; then
        log_error "环境检查失败"
        exit 1
    fi

    # 2. 版本兼容性检查
    log_info "步骤 2: 版本兼容性检查..."
    if ! check_version_compatibility; then
        log_error "版本兼容性检查失败"
        exit 1
    fi

    # 3. 检查是否已安装
    log_info "步骤 3: 检查是否已安装..."
    if grep -q "clash_api" "${GENERATE_CLIENT_UC}"; then
        log_warn "Clash API 已安装"
        read -p "是否重新安装？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消安装"
            exit 0
        fi
    fi

    # 4. 创建备份
    if [ "${ENABLE_BACKUP}" == "true" ]; then
        log_info "步骤 4: 创建备份..."
        BACKUP_DIR=$(create_backup)
        if [ $? -ne 0 ]; then
            log_error "备份创建失败"
            exit 1
        fi
        log_info "备份创建成功: ${BACKUP_DIR}"
    fi

    # 5. 设置错误处理
    if [ "${ENABLE_ROLLBACK}" == "true" ]; then
        setup_error_handler
    fi

    # 6. 读取用户配置
    log_info "步骤 5: 读取用户配置..."
    read_user_config

    # 7. 修改文件
    log_info "步骤 6: 修改文件..."
    modify_generate_client_uc
    modify_client_js

    # 8. 应用 UCI 配置
    log_info "步骤 7: 应用 UCI 配置..."
    apply_uci_config

    # 9. 验证修改
    if [ "${ENABLE_VERIFICATION}" == "true" ]; then
        log_info "步骤 8: 验证修改..."
        if ! verify_file_modifications; then
            log_error "文件修改验证失败"
            exit 1
        fi

        if ! validate_uci_config; then
            log_error "UCI 配置验证失败"
            exit 1
        fi
    fi

    # 10. 清理旧备份
    cleanup_old_backups

    # 11. 显示完成信息
    log_info "=== Clash API 安装完成 ==="
    echo ""
    echo "安装成功！"
    echo "备份文件: ${BACKUP_DIR}"
    echo ""
    echo "下一步："
    echo "1. 下载 Clash WebUI 到 ${CLASH_API_UI} 目录"
    echo "2. 在 LuCI 界面中启用 Clash API"
    echo "3. 配置外部控制器地址"
    echo ""
    echo "如需卸载，请运行: ${SCRIPT_DIR}/remove_clash_api.sh"
    echo ""

    # 12. 询问是否删除备份
    read -p "是否删除备份文件？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${BACKUP_DIR}"
        log_info "备份已删除"
    fi
}

# 运行主函数
main "$@"