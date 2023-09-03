#!/usr/bin/env bash
set -e

wget https://api.azzb.club/https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt -O /tmp/china.txt
ipset flush whitelist
ip=$(cat /tmp/china.txt)
for i in $ip; do
  ipset add whitelist "$i"
done
ipset save whitelist -f /home/ubuntu/white.ipset
