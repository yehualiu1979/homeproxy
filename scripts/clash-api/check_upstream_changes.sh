#!/bin/bash
# 检测上游更新对 Clash API 的影响

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config/clash_api.conf"
source "${SCRIPT_DIR}/lib/common.sh"

log_info "=== 上游更新影响检测 ==="

# 关键文件列表
KEY_FILES=(
    "${GENERATE_CLIENT_UC}"
    "${CLIENT_JS}"
    "${UCI_CONFIG}"
)

# 关键标记列表
KEY_MARKERS=(
    "Experimental start"
    "Experimental end"
    "Custom routing settings start"
    "Custom routing settings end"
)

# 检查 git 状态
check_git_status() {
    log_info "检查 Git 状态..."

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warn "不是 Git 仓库"
        return 1
    fi

    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        log_warn "工作区有未提交的更改"
        git status --short
    fi

    return 0
}

# 检查上游更新
check_upstream_updates() {
    log_info "检查上游更新..."

    git fetch origin master 2>/dev/null || {
        log_warn "无法获取上游更新"
        return 1
    }

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/master)

    if [ "${LOCAL}" = "${REMOTE}" ]; then
        log_info "已经是最新版本"
        return 0
    fi

    log_info "发现上游更新："
    git log HEAD..origin/master --oneline | head -n 10

    # 检查关键文件的修改
    log_info "检查关键文件修改："
    git diff HEAD..origin/master --name-only | grep -E "(generate_client\.uc|client\.js|homeproxy)$" || log_info "关键文件未修改"

    return 0
}

# 检查标记完整性
check_markers_integrity() {
    log_info "检查标记完整性..."

    local errors=0

    for file in "${KEY_FILES[@]}"; do
        if [ ! -f "${file}" ]; then
            log_error "文件不存在: ${file}"
            errors=$((errors + 1))
            continue
        fi

        log_info "检查文件: ${file}"

        for marker in "${KEY_MARKERS[@]}"; do
            if grep -q "${marker}" "${file}"; then
                log_debug "  ✓ 找到标记: ${marker}"
            else
                log_warn "  ✗ 未找到标记: ${marker}"
                errors=$((errors + 1))
            fi
        done
    done

    return ${errors}
}

# 检查 Clash API 状态
check_clash_api_status() {
    log_info "检查 Clash API 安装状态..."

    local installed=0

    if grep -q "clash_api" "${GENERATE_CLIENT_UC}" 2>/dev/null; then
        log_info "  ✓ generate_client.uc 已安装 Clash API"
        installed=$((installed + 1))
    else
        log_warn "  ✗ generate_client.uc 未安装 Clash API"
    fi

    if grep -q "Clash API settings" "${CLIENT_JS}" 2>/dev/null; then
        log_info "  ✓ client.js 已安装 Clash API"
        installed=$((installed + 1))
    else
        log_warn "  ✗ client.js 未安装 Clash API"
    fi

    if grep -q "^config homeproxy 'clash_api'" "${UCI_CONFIG}" 2>/dev/null; then
        log_info "  ✓ UCI 配置已安装 Clash API"
        installed=$((installed + 1))
    else
        log_warn "  ✗ UCI 配置未安装 Clash API"
    fi

    return $((3 - installed))
}

# 生成建议
generate_recommendations() {
    log_info "=== 生成建议 ==="

    # 检查 Git 状态
    check_git_status
    local git_status=$?

    # 检查上游更新
    check_upstream_updates
    local has_updates=$?

    # 检查标记完整性
    check_markers_integrity
    local markers_ok=$?

    # 检查 Clash API 状态
    check_clash_api_status
    local clash_api_ok=$?

    echo ""
    echo "=== 检测结果 ==="
    echo ""

    if [ ${has_updates} -eq 0 ] && [ ${git_status} -eq 0 ]; then
        echo "✓ 无上游更新，无需操作"
        return 0
    fi

    if [ ${markers_ok} -ne 0 ]; then
        echo "⚠️  关键标记丢失，上游更新可能影响了代码结构"
        echo ""
        echo "建议操作："
        echo "1. 手动检查关键文件的修改"
        echo "2. 如果标记位置改变，需要更新脚本"
        echo "3. 运行: bash ${SCRIPT_DIR}/test_install.sh 进行测试"
        return 1
    fi

    if [ ${clash_api_ok} -ne 0 ]; then
        echo "⚠️  Clash API 配置不完整"
        echo ""
        echo "建议操作："
        echo "bash ${SCRIPT_DIR}/add_clash_api.sh"
        return 1
    fi

    if [ ${has_updates} -ne 0 ]; then
        echo "⚠️  发现上游更新"
        echo ""
        echo "建议操作："
        echo "1. 先同步上游: git pull origin master"
        echo "2. 运行测试: bash ${SCRIPT_DIR}/test_install.sh"
        echo "3. 重新安装: bash ${SCRIPT_DIR}/add_clash_api.sh"
        echo "4. 验证安装: bash ${SCRIPT_DIR}/verify_installation.sh"
        return 1
    fi

    echo "✓ 所有检查通过，无需额外操作"
    return 0
}

# 主函数
main() {
    generate_recommendations
    exit $?
}

main "$@"