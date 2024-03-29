#!/usr/bin/env bash
set -e
[[ $EUID -ne 0 ]] && echo "请以root身份执行该脚本！" && exit 1
wget https://api.iristory.top/https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt -O /tmp/china.txt
ipset flush whitelist
ip=$(cat /tmp/china.txt)
for i in $ip; do
  ipset add whitelist "$i"
done
ipset save whitelist -f /home/ubuntu/white.ipset
