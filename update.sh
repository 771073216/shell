#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

TMP_DIR="$(mktemp -du)"
v2link=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

check() {
  if command -v "v2ray" > /dev/null 2>&1; then
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    update_v2ray
    rm -rf "$TMP_DIR"
  else
    echo -e "[${red}Error${plain}] v2ray is not installed!"
    exit 1
  fi
}

update() {
  echo -e "[${green}Info${plain}] 获取${yellow}v2ray${plain}版本信息..."
  latest=$(wget -qO- "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  [ -z "${latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
  current=v$(/usr/local/bin/v2ray -version | awk 'NR==1 {print $2}')
  if [ "${latest}" == "${current}" ]; then
    echo -e "[${green}Info${plain}] ${yellow}V2Ray${plain}已安装最新版本${green}${latest}${plain}。"
  else
    echo -e "[${green}Info${plain}] 正在更新${yellow}V2Ray${plain}：${red}${current}${plain} --> ${green}${latest}${plain}"
    wget -c "https://api.azzb.workers.dev/$v2link"
    unzip -oq "v2ray-linux-64.zip"
    install -m 755 "v2ray" /usr/local/bin/
    systemctl restart v2ray
    echo -e "[${green}Info${plain}] ${yellow}v2ray${plain}更新成功！"
  fi
}

check
