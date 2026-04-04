#!/bin/bash
# Clash API 卸载脚本

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置和函数库
source "${SCRIPT_DIR}/config/clash_api.conf"
source "${SCRIPT_DIR}/lib/common.sh"

log_info "=== Clash API 卸载脚本开始 ==="

# 1. 检查是否已安装
if ! grep -q "clash_api" "${GENERATE_CLIENT_UC}"; then
    log_warn "Clash API 未安装"
    exit 0
fi

# 2. 创建备份
BACKUP_DIR=$(create_backup)
log_info "备份已创建: ${BACKUP_DIR}"

# 3. 移除 UCI 配置
sed -i "/^config homeproxy 'clash_api'/,/^$/d" "${UCI_CONFIG}"
log_info "UCI 配置已移除"

# 4. 移除 generate_client.uc 中的 Clash API 代码
sed -i "/\/\* Clash API config start \*\//,/\* Clash API config end \*\//d" "${GENERATE_CLIENT_UC}"
log_info "generate_client.uc 已恢复"

# 5. 移除 client.js 中的 Clash API 界面
sed -i "/\/\* Clash API settings start \*\//,/\* Clash API settings end \*\//d" "${CLIENT_JS}"
log_info "client.js 已恢复"

# 6. 移除 experimental 中的 clash_api
sed -i '/clash_api: {/,/}/d' "${GENERATE_CLIENT_UC}"
log_info "experimental 配置已恢复"

# 7. 恢复 experimental 条件
sed -i "s/if (routing_mode in \['bypass_mainland_china', 'custom'\] \|\| strToBool(clash_api_enabled))/if (routing_mode in ['bypass_mainland_china', 'custom'])/" "${GENERATE_CLIENT_UC}"

log_info "=== Clash API 卸载完成 ==="
echo "备份文件: ${BACKUP_DIR}"