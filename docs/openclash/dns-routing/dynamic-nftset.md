# Lenovo 企业域名动态 nftset

dnsmasq 把 `lenovo.com`、`mot.com` 和 `motorola.com` 的 IPv4 解析结果写入
`inet fw4 lenovo_dns_ips`。OpenClash 自定义脚本在 `@localnetwork return`
前为该集合中的目标设置 `0x162` mark。

路由器持久化配置：

```sh
uci set firewall.lenovo_dns_ips='ipset'
uci set firewall.lenovo_dns_ips.name='lenovo_dns_ips'
uci set firewall.lenovo_dns_ips.family='ipv4'
uci -q delete firewall.lenovo_dns_ips.match
uci add_list firewall.lenovo_dns_ips.match='dest_ip'
uci commit firewall

uci set dhcp.@dnsmasq[0].extraconftext='nftset=/lenovo.com/mot.com/motorola.com/4#inet#fw4#lenovo_dns_ips'
uci commit dhcp
```

验证：

```sh
grep -R 'nftset=.*lenovo_dns_ips' /tmp/dnsmasq.*.d /var/etc/dnsmasq* 2>/dev/null
nft list set inet fw4 lenovo_dns_ips
nft list chain inet fw4 openclash_mangle | grep 'Lenovo DNS Learned TUN'
```

静态 `lenovo_ips` 仅作为裸 IP 和迁移期兜底；动态方案稳定后再缩减。
