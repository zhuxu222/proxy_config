#!/bin/sh
# ============================================================
# 企业内网 IP 绕过 localnetwork 限制脚本
#
# 问题：
#   企业内网域名（如 *.lenovo.com, *.mot.com）解析到私网 IP，
#   被 nftables @localnetwork 集合拦截后 return，无法进入 TUN 代理。
#
# 方案：
#   从配置文件读取需要代理的内网 IP/CIDR 列表，
#   在 @localnetwork return 之前插入 nftables 规则，
#   将匹配的流量打上 fwmark 强制进入 TUN。
#
# 用法：
#   sh intranet_tun_bypass.sh [配置文件路径]
#   默认配置文件：同目录下的 lenovo_intranet_ips.list
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTRANET_LIST="${1:-$SCRIPT_DIR/lenovo_intranet_ips.list}"
NFT_SET_NAME="lenovo_ips"
NFT_TABLE="inet fw4"
FWMARK="0x00000162"
LOG_TAG="IntranetBypass"
MAX_RETRY=30
RETRY_INTERVAL=2

log_msg() {
    if type LOG_OUT >/dev/null 2>&1; then
        LOG_OUT "$LOG_TAG: $1"
    else
        echo "[$LOG_TAG] $1"
    fi
}

# 提取 nftables handle 编号（兼容 BusyBox grep/awk）
get_handle() {
    nft -a list chain $NFT_TABLE "$1" 2>/dev/null \
        | grep "localnetwork" \
        | awk '{for(i=1;i<=NF;i++) if($i=="handle") print $(i+1)}' \
        | head -1
}

# 检查配置文件
if [ ! -f "$INTRANET_LIST" ]; then
    log_msg "Error: config not found: $INTRANET_LIST"
    return 1 2>/dev/null || exit 1
fi

# 从配置文件读取 IP 列表（过滤注释和空行，拼成逗号分隔）
IP_ELEMENTS=$(grep -v '^\s*#' "$INTRANET_LIST" | grep -v '^\s*$' | tr '\n' ',' | sed 's/,$//')

if [ -z "$IP_ELEMENTS" ]; then
    log_msg "Warning: no IPs found in $INTRANET_LIST"
    return 0 2>/dev/null || exit 0
fi

log_msg "Loading IPs: $IP_ELEMENTS"

# 等待 OpenClash nftables 链就绪，然后创建 set 并插入规则
insert_rules() {
    local retry=0

    while [ $retry -lt $MAX_RETRY ]; do
        HANDLE_M=$(get_handle openclash_mangle)
        HANDLE_O=$(get_handle openclash_mangle_output)

        if [ -n "$HANDLE_M" ] && [ -n "$HANDLE_O" ]; then
            # 创建/重建 nftables set（O(1) 哈希匹配）
            nft add set $NFT_TABLE $NFT_SET_NAME "{ type ipv4_addr; flags interval; auto-merge; }" 2>/dev/null
            nft flush set $NFT_TABLE $NFT_SET_NAME 2>/dev/null
            nft add element $NFT_TABLE $NFT_SET_NAME "{ $IP_ELEMENTS }"

            if [ $? -ne 0 ]; then
                log_msg "Error: failed to add elements to $NFT_SET_NAME"
                return 1
            fi

            # 在 openclash_mangle 链的 @localnetwork return 之前插入规则
            nft insert rule $NFT_TABLE openclash_mangle position "$HANDLE_M" \
                ip daddr @${NFT_SET_NAME} meta l4proto "{ tcp, udp }" \
                meta mark set $FWMARK counter \
                comment "\"Intranet TUN Bypass\"" 2>/dev/null
            log_msg "mangle rule inserted (handle $HANDLE_M)"

            # 在 openclash_mangle_output 链的 @localnetwork return 之前插入规则
            nft insert rule $NFT_TABLE openclash_mangle_output position "$HANDLE_O" \
                ip daddr @${NFT_SET_NAME} meta l4proto "{ tcp, udp }" \
                meta mark set $FWMARK counter \
                comment "\"Intranet TUN Bypass\"" 2>/dev/null
            log_msg "mangle_output rule inserted (handle $HANDLE_O)"

            log_msg "Done"
            return 0
        fi

        retry=$((retry + 1))
        log_msg "Waiting for OpenClash nftables chains... ($retry/$MAX_RETRY)"
        sleep $RETRY_INTERVAL
    done

    log_msg "Error: OpenClash nftables chains not found after ${MAX_RETRY} retries"
    return 1
}

# 后台执行等待+插入，不阻塞 OpenClash 启动流程
insert_rules &

log_msg "Started (background)"
