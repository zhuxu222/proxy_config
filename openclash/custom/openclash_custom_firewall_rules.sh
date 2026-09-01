#!/bin/sh
. /usr/share/openclash/log.sh
. /lib/functions.sh

# This script is called by /etc/init.d/openclash
# Add your custom firewall rules here, they will be added after the end of the OpenClash iptables rules

LOG_OUT "Tip: Start Add Custom Firewall Rules..."

# 企业内网 IP 绕过 localnetwork 限制，强制进入 TUN 代理。
# OpenClash 的 localnetwork 规则会提前放行 10.x/100.64.x 等地址，导致 Lenovo VPN 规则无法命中。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/intranet_tun_bypass.sh"

# 企业域名解析结果由 dnsmasq 自动加入动态 nft set。
. "$SCRIPT_DIR/lenovo_dns_nftset.sh"

exit 0
