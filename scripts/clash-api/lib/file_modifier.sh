#!/bin/bash
# 文件修改模块

# 修改 generate_client.uc
modify_generate_client_uc() {
    local file="${GENERATE_CLIENT_UC}"

    log_info "修改 ${file}..."

    # 1. 添加 UCI 配置读取
    if ! grep -q "uciclashapi" "${file}"; then
        # 创建临时文件存储 UCI 配置块
        local temp_uci="/tmp/uci_config_$$.uc"
        cat > "${temp_uci}" <<'EOF'

/* Clash API config start */
const uciclashapi = 'clash_api';
const clash_api_enabled = uci.get(uciconfig, uciclashapi, 'enabled') || '0';
const clash_api_controller = uci.get(uciconfig, uciclashapi, 'external_controller') || '127.0.0.1:9090';
const clash_api_ui = uci.get(uciconfig, uciclashapi, 'external_ui') || '/etc/homeproxy/ui/';
const clash_api_ui_detour = uci.get(uciconfig, uciclashapi, 'external_ui_download_detour') || '';
const clash_api_default_mode = uci.get(uciconfig, uciclashapi, 'default_mode') || 'rule';
const clash_api_secret = uci.get(uciconfig, uciclashapi, 'secret') || '';
/* Clash API config end */
EOF

        # 在 ucidnsserver 定义后插入
        awk -v insert_file="${temp_uci}" '
            /ucidnsserver = .dns_server/ {
                while ((getline line < insert_file) > 0) {
                    print line
                }
                close(insert_file)
            }
            { print }
        ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"

        rm -f "${temp_uci}"
    fi

    # 2. 修改 experimental 配置
    if ! grep -q "clash_api:" "${file}"; then
        # 找到 cache_file 配置的结束位置，然后添加 clash_api
        # 使用更精确的 awk 命令，在 cache_file 块的结束 `}` 之后插入
        awk '
            BEGIN {
                in_cache_file = 0
                brace_count = 0
            }
            /cache_file: \{/ {
                in_cache_file = 1
                brace_count = 1
                print
                next
            }
            in_cache_file {
                # 跟踪花括号计数
                if (/\{/) brace_count++
                if (/\}/) brace_count--
                
                print
                
                # 当 cache_file 块结束时（brace_count 回到 0）
                if (brace_count == 0) {
                    in_cache_file = 0
                    # 在这里插入 clash_api 配置
                    print "\t\t},"
                    print "\t\tclash_api: {"
                    print "\t\t\texternal_controller: clash_api_controller,"
                    print "\t\t\texternal_ui: clash_api_ui,"
                    print "\t\t\texternal_ui_download_detour: clash_api_ui_detour || null,"
                    print "\t\t\tdefault_mode: clash_api_default_mode,"
                    print "\t\t\tsecret: clash_api_secret || null"
                    print "\t\t}"
                }
                next
            }
            { print }
        ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
    fi

    # 3. 修改 experimental 条件
    sed -i "s/if (routing_mode in \['bypass_mainland_china', 'custom'\])/if (routing_mode in ['bypass_mainland_china', 'custom'] \|\| strToBool(clash_api_enabled))/" "${file}"

    log_info "${file} 修改完成"
}

# 修改 client.js
modify_client_js() {
    local file="${CLIENT_JS}"

    log_info "修改 ${file}..."

    # 创建临时文件存储 Clash API 配置
    local temp_content="/tmp/clash_api_tab_$$.js"
    cat > "${temp_content}" <<'EOF'

		/* Clash API settings start */
		s.tab('clash_api', _('Clash API'));
		o = s.taboption('clash_api', form.SectionValue, '_clash_api', form.NamedSection, 'clash_api', 'homeproxy');
		o.depends('routing_mode', 'custom');

		ss = o.subsection;

		so = ss.option(form.Flag, 'enabled', _('Enable Clash API'));
		so.default = so.disabled;
		so.rmempty = false;

		so = ss.option(form.Value, 'external_controller', _('External controller'),
			_('External controller address, e.g., 127.0.0.1:9090'));
		so.datatype = 'hostport';
		so.placeholder = '127.0.0.1:9090';
		so.depends('enabled', '1');

		so = ss.option(form.Value, 'external_ui', _('External UI'),
			_('Web UI directory path, e.g., /etc/homeproxy/ui/'));
		so.datatype = 'directory';
		so.placeholder = '/etc/homeproxy/ui/';
		so.depends('enabled', '1');

		so = ss.option(hp.CBIStaticList, 'external_ui_download_detour', _('UI download detour'),
			_('Outbound used to download UI resources.'));
		so.depends('enabled', '1');

		so = ss.option(form.ListValue, 'default_mode', _('Default mode'),
			_('Default clash mode.'));
		so.value('rule', _('Rule'));
		so.value('direct', _('Direct'));
		so.value('global', _('Global'));
		so.default = 'rule';
		so.depends('enabled', '1');

		so = ss.option(form.Value, 'secret', _('Secret'),
			_('Secret for authentication (optional).'));
		so.password = true;
		so.depends('enabled', '1');
		/* Clash API settings end */
EOF

    # 在 Custom routing settings end 之前插入
    awk -v insert_file="${temp_content}" '
        /Custom routing settings end/ {
            while ((getline line < insert_file) > 0) {
                print line
            }
            close(insert_file)
        }
        { print }
    ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"

    rm -f "${temp_content}"

    log_info "${file} 修改完成"
}

# 验证文件修改
verify_file_modifications() {
    local errors=0

    # 检查 generate_client.uc
    if ! grep -q "clash_api" "${GENERATE_CLIENT_UC}"; then
        log_error "generate_client.uc 未包含 clash_api 配置"
        errors=$((errors + 1))
    fi

    if ! grep -q "Clash API settings" "${CLIENT_JS}"; then
        log_error "client.js 未包含 Clash API 设置界面"
        errors=$((errors + 1))
    fi

    return ${errors}
}