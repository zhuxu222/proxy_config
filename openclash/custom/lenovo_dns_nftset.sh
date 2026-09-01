#!/bin/sh
# dnsmasq 将企业域名的 A 记录写入 lenovo_dns_ips。
# 本脚本确保动态 set 存在，并在 @localnetwork return 前强制进入 TUN。

NFT_TABLE="inet fw4"
NFT_SET_NAME="lenovo_dns_ips"
FWMARK="0x00000162"
LOG_TAG="LenovoDnsNftset"
RULE_COMMENT="Lenovo DNS Learned TUN"
MAX_RETRY=30
RETRY_INTERVAL=2

log_msg() {
    if type LOG_OUT >/dev/null 2>&1; then
        LOG_OUT "$LOG_TAG: $1"
    else
        echo "[$LOG_TAG] $1"
    fi
}

chain_exists() {
    nft list chain $NFT_TABLE "$1" >/dev/null 2>&1
}

ensure_set() {
    nft list set $NFT_TABLE "$NFT_SET_NAME" >/dev/null 2>&1 && return 0
    nft add set $NFT_TABLE "$NFT_SET_NAME" "{ type ipv4_addr; flags interval; auto-merge; }"
}

delete_old_rules() {
    local chain="$1"
    nft -a list chain $NFT_TABLE "$chain" 2>/dev/null \
        | grep "$RULE_COMMENT" \
        | awk '{for(i=1;i<=NF;i++) if($i=="handle") print $(i+1)}' \
        | sort -rn \
        | while read -r handle; do
            [ -n "$handle" ] && nft delete rule $NFT_TABLE "$chain" handle "$handle" 2>/dev/null
        done
}

insert_rule() {
    local chain="$1"
    delete_old_rules "$chain"
    nft insert rule $NFT_TABLE "$chain" \
        ip daddr @${NFT_SET_NAME} meta l4proto "{ tcp, udp }" \
        meta mark set $FWMARK counter \
        comment "\"$RULE_COMMENT\""
}

activate_rules() {
    local retry=0

    while [ $retry -lt $MAX_RETRY ]; do
        if chain_exists openclash_mangle && chain_exists openclash_mangle_output; then
            if ! ensure_set; then
                log_msg "Error: failed to create $NFT_SET_NAME"
                return 1
            fi

            insert_rule openclash_mangle || return 1
            insert_rule openclash_mangle_output || return 1

            # dnsmasq 可能缓存了 set 创建前的应答。HUP 只清 DNS 缓存，
            # 不停止 DHCP 服务；后续查询会重新填充动态 set。
            DNSMASQ_PIDS="$(pidof dnsmasq)"
            [ -z "$DNSMASQ_PIDS" ] || kill -HUP $DNSMASQ_PIDS 2>/dev/null

            log_msg "Dynamic rules ready"
            return 0
        fi

        retry=$((retry + 1))
        log_msg "Waiting for OpenClash nftables chains... ($retry/$MAX_RETRY)"
        sleep $RETRY_INTERVAL
    done

    log_msg "Error: OpenClash nftables chains not found after ${MAX_RETRY} retries"
    return 1
}

activate_rules &
log_msg "Started (background)"
