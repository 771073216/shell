#!/usr/bin/env bash
set -e
[[ $EUID -ne 0 ]] && echo "请以root身份执行该脚本！" && exit 1

ipset restore -f /home/ubuntu/white.ipset

iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -m set ! --match-set whitelist src -j REJECT --reject-with icmp-host-prohibited

iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 5000 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 11000:11001 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 12000:12001 -j ACCEPT
iptables -A INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -A FORWARD -j REJECT --reject-with icmp-host-prohibited
