#!/bin/bash
# 版本检测模块

# 获取 sing-box 版本
get_singbox_version() {
    sing-box version 2>/dev/null | grep -oP 'version \K[\d.]+' || echo "unknown"
}

# 比较版本号
compare_versions() {
    local version1="$1"
    local version2="$2"

    # 移除非数字字符
    version1=$(echo "${version1}" | grep -oP '[\d.]+')
    version2=$(echo "${version2}" | grep -oP '[\d.]+')

    # 先判断是否相等
    if [ "${version1}" == "${version2}" ]; then
        echo "equal"
    # 使用 sort 进行版本比较
    elif [ "$(echo -e "${version1}\n${version2}" | sort -V | head -n1)" == "${version1}" ]; then
        echo "less"
    else
        echo "greater"
    fi
}

# 检查版本兼容性
check_version_compatibility() {
    local singbox_version=$(get_singbox_version)
    local min_version="${SINGBOX_MIN_VERSION}"

    log_info "检查版本兼容性..."
    log_info "当前版本: ${singbox_version}"
    log_info "最低要求: ${min_version}"

    local comparison=$(compare_versions "${singbox_version}" "${min_version}")

    case "${comparison}" in
        "older")
            log_error "sing-box 版本过低，请升级到 ${min_version} 或更高版本"
            return 1
            ;;
        "equal"|"newer")
            log_info "版本兼容性检查通过"
            return 0
            ;;
        *)
            log_error "无法确定版本兼容性"
            return 1
            ;;
    esac
}

# 获取配置版本
get_config_version() {
    local singbox_version=$(get_singbox_version)
    local version_map="${SCRIPT_DIR}/config/version_map.txt"

    if [ ! -f "${version_map}" ]; then
        echo "1.0"
        return 0
    fi

    local config_version=$(grep "^${singbox_version}:" "${version_map}" | cut -d: -f2)

    if [ -z "${config_version}" ]; then
        # 使用默认配置版本
        config_version="1.0"
    fi

    echo "${config_version}"
}

# 获取已安装的配置版本
get_installed_config_version() {
    # 从备份或配置文件中读取
    if grep -q "CLASH_API_CONFIG_VERSION" "${GENERATE_CLIENT_UC}" 2>/dev/null; then
        grep "CLASH_API_CONFIG_VERSION" "${GENERATE_CLIENT_UC}" | grep -oP 'CLASH_API_CONFIG_VERSION.*?\K[\d.]+' || echo "0.0"
    else
        echo "0.0"
    fi
}