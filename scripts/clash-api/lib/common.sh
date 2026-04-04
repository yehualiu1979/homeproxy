#!/bin/bash
# 通用函数库

# 日志函数
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_debug() { [[ "${LOG_LEVEL}" == "DEBUG" ]] && log "DEBUG" "$@"; }
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件是否存在
file_exists() {
    [ -f "$1" ]
}

# 检查目录是否存在
dir_exists() {
    [ -d "$1" ]
}

# 创建备份
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${BACKUP_DIR}_${timestamp}"

    mkdir -p "${backup_dir}" || return 1

    # 备份关键文件
    for file in "${GENERATE_CLIENT_UC}" "${CLIENT_JS}" "${UCI_CONFIG}"; do
        if [ -f "${file}" ]; then
            cp "${file}" "${backup_dir}/$(basename ${file}).bak" || return 1
        fi
    done

    # 记录备份信息
    cat > "${backup_dir}/backup_info.txt" <<EOF
Backup Time: $(date)
Backup Dir: ${backup_dir}
Project Root: ${PROJECT_ROOT}
Files Backed Up:
- ${GENERATE_CLIENT_UC}
- ${CLIENT_JS}
- ${UCI_CONFIG}
EOF

    echo "${backup_dir}"
}

# 恢复备份
restore_backup() {
    local backup_dir="$1"

    if [ ! -d "${backup_dir}" ]; then
        log_error "备份目录不存在: ${backup_dir}"
        return 1
    fi

    log_info "正在恢复备份: ${backup_dir}"

    # 恢复文件
    for file in "${GENERATE_CLIENT_UC}" "${CLIENT_JS}" "${UCI_CONFIG}"; do
        local backup_file="${backup_dir}/$(basename ${file}).bak"
        if [ -f "${backup_file}" ]; then
            cp "${backup_file}" "${file}" || return 1
            log_info "已恢复: ${file}"
        fi
    done

    log_info "备份恢复完成"
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理 ${BACKUP_RETENTION_DAYS} 天前的备份..."

    find "${BACKUP_DIR}"* -maxdepth 0 -type d -mtime +${BACKUP_RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null

    log_info "备份清理完成"
}

# 检查文件权限
check_file_permissions() {
    local file="$1"
    local expected_perms="$2"

    local actual_perms=$(stat -c "%a" "${file}" 2>/dev/null)

    if [ "${actual_perms}" != "${expected_perms}" ]; then
        log_warn "文件权限异常: ${file} (期望: ${expected_perms}, 实际: ${actual_perms})"
        return 1
    fi

    return 0
}

# 检查 sing-box 版本
check_singbox_version() {
    if ! command_exists sing-box; then
        log_error "sing-box 未安装"
        return 1
    fi

    local version=$(sing-box version 2>/dev/null | grep -oP 'version \K[\d.]+' || echo "0.0.0")
    local min_version="${SINGBOX_MIN_VERSION}"

    log_info "检测到 sing-box 版本: ${version}"
    log_info "要求的最低版本: ${min_version}"

    # 简单的版本比较
    if [ "$(echo -e "${version}\n${min_version}" | sort -V | head -n1)" != "${min_version}" ]; then
        log_error "sing-box 版本过低 (${version} < ${min_version})"
        return 1
    fi

    return 0
}

# 读取配置文件
read_config() {
    local config_file="${SCRIPT_DIR}/config/clash_api.conf"

    if [ ! -f "${config_file}" ]; then
        log_error "配置文件不存在: ${config_file}"
        return 1
    fi

    # 加载配置
    source "${config_file}"
}

# 设置错误处理
setup_error_handler() {
    set -e
    trap 'handle_error ${LINENO}' ERR
}

handle_error() {
    local line_no=$1
    log_error "脚本在第 ${line_no} 行出错"

    if [ "${ENABLE_ROLLBACK}" == "true" ]; then
        log_info "正在执行自动回滚..."
        if [ -n "${BACKUP_DIR}" ]; then
            restore_backup "${BACKUP_DIR}"
        fi
    fi

    exit 1
}