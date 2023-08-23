#!/usr/bin/env bash
[[ $EUID -ne 0 ]] && echo "请以root身份执行该脚本！" && exit 1
iptables -F
iptables -A INPUT -m set --match-set whitelist src -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 5000 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 10000:10001 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 12000:12001 -j ACCEPT
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited
netfilter-persistent save
