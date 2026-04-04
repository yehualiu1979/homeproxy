#!/bin/bash
# 安装验证脚本

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置和函数库
source "${SCRIPT_DIR}/config/clash_api.conf"
source "${SCRIPT_DIR}/lib/common.sh"

log_info "=== Clash API 安装验证 ==="

errors=0

# 检查文件
if ! grep -q "clash_api" "${GENERATE_CLIENT_UC}"; then
    log_error "generate_client.uc 缺少 clash_api 配置"
    errors=$((errors + 1))
fi

if ! grep -q "Clash API settings" "${CLIENT_JS}"; then
    log_error "client.js 缺少 Clash API 设置界面"
    errors=$((errors + 1))
fi

if ! grep -q "^config homeproxy 'clash_api'" "${UCI_CONFIG}"; then
    log_error "UCI 配置缺少 clash_api section"
    errors=$((errors + 1))
fi

if [ ${errors} -eq 0 ]; then
    log_info "=== 验证通过 ==="
    exit 0
else
    log_error "=== 验证失败，发现 ${errors} 个错误 ==="
    exit 1
fi