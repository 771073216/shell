#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'
	echo -en "[${green}Info${plain}] 请输入链接：" && read -r link
	a=$(($(echo "$link" | grep -o '/' | wc -l)+1))
	file=$(echo "$link" | cut -d/ -f$a)
	wget -c -t3 -T5 "$link" -O "$file"
	mv "$file" /var/www/html
	echo -e "下载链接：${red}https://www.azzb.club/$file${plain}"
