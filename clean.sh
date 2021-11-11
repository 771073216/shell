#!/usr/bin/env bash
y=$(date "+%Y" -d '3 days ago')
m=$(date "+%m" -d '3 days ago')
d=$(date "+%d" -d '3 days ago')
sed -i "/$y\/$m\/$d/d" /var/log/xray/access.log
