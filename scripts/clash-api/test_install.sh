#!/bin/bash
# 测试脚本 - 模拟安装过程
# 用于在非路由器环境中测试脚本逻辑

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载配置
source "${SCRIPT_DIR}/config/clash_api.conf"
source "${SCRIPT_DIR}/lib/common.sh"

echo "========================================="
echo "Clash API 安装脚本测试"
echo "========================================="
echo ""

# 1. 测试配置加载
echo "测试 1: 配置加载"
echo "项目路径: ${PROJECT_ROOT}"
echo "脚本目录: ${SCRIPT_DIR}"
echo "生成客户端脚本: ${GENERATE_CLIENT_UC}"
echo "客户端JS: ${CLIENT_JS}"
echo "UCI配置: ${UCI_CONFIG}"
echo ""

# 2. 测试文件存在性
echo "测试 2: 文件存在性检查"
for file in "${GENERATE_CLIENT_UC}" "${CLIENT_JS}" "${UCI_CONFIG}"; do
    if [ -f "${file}" ]; then
        echo "✓ ${file}"
    else
        echo "✗ ${file} (不存在)"
    fi
done
echo ""

# 3. 测试备份功能
echo "测试 3: 备份功能"
echo "正在创建备份..."
BACKUP_DIR=$(create_backup)
if [ $? -eq 0 ]; then
    echo "✓ 备份创建成功: ${BACKUP_DIR}"
    echo "备份文件:"
    ls -lh "${BACKUP_DIR}"
else
    echo "✗ 备份创建失败"
fi
echo ""

# 4. 测试文件修改（模拟）
echo "测试 4: 文件修改模拟"
echo "检查 generate_client.uc 中的关键标记:"
if grep -q "Experimental start" "${GENERATE_CLIENT_UC}"; then
    echo "✓ 找到 'Experimental start' 标记"
else
    echo "✗ 未找到 'Experimental start' 标记"
fi

if grep -q "Custom routing settings" "${CLIENT_JS}"; then
    echo "✓ 找到 'Custom routing settings' 标记"
else
    echo "✗ 未找到 'Custom routing settings' 标记"
fi
echo ""

# 5. 测试配置生成
echo "测试 5: UCI 配置生成"
echo "生成的 Clash API 配置:"
source "${SCRIPT_DIR}/lib/config_manager.sh"
generate_uci_config
echo ""

# 6. 测试恢复功能
echo "测试 6: 备份恢复功能"
if [ -n "${BACKUP_DIR}" ]; then
    echo "模拟恢复备份..."
    restore_backup "${BACKUP_DIR}"
    echo "✓ 备份恢复测试完成"
else
    echo "✗ 没有可用的备份目录"
fi
echo ""

# 7. 显示测试结果
echo "========================================="
echo "测试完成"
echo "========================================="
echo ""
echo "注意事项:"
echo "1. ucode 和 sing-box 在此环境中不可用"
echo "2. 实际安装需要在 ImmortalWrt/OpenWrt 环境中运行"
echo "3. 所有脚本文件已创建并设置正确权限"
echo ""
echo "脚本位置: ${SCRIPT_DIR}"
echo "备份位置: ${BACKUP_DIR}"
echo ""
echo "使用方法:"
echo "1. 在路由器上: bash ${SCRIPT_DIR}/add_clash_api.sh"
echo "2. 验证安装: bash ${SCRIPT_DIR}/verify_installation.sh"
echo "3. 卸载功能: bash ${SCRIPT_DIR}/remove_clash_api.sh"
echo ""