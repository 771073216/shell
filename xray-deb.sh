#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1

install_xray() {
  if dpkg -l | grep xray > /dev/null; then
    update_xray
  fi
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  echo -e -n "[${g}Info${p}] 输入密码： "
  read -r passwd
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/deb@main/xray.deb -O xray.deb
  dpkg -i xray.deb && rm xray.deb
  sed -i "s/passwd/$passwd/g" /usr/local/etc/xray/config.yaml
  sed -i "s/owndomain/$domain/g" /usr/local/etc/xray/config.yaml
  sed -i "1c$domain {" /usr/local/etc/caddy/Caddyfile
  systemctl restart xray caddy
  info_xray
}

update_xray() {
  remote_version=$(wget -qO- "https://cdn.jsdelivr.net/gh/771073216/deb@main/version" | tr "\n" " " | awk '{print$2 "+" $4}')
  local_version=$(dpkg -s xray | awk '/Version/ {print$2}')
  if ! [ "${remote_version}" == "${local_version}" ]; then
    echo -e "| ${y}xray+caddy${p}  | ${r}${local_version}${p} --> ${g}${remote_version}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/deb@main/xray.deb -O xray.deb
    echo | dpkg -i xray.deb && rm xray.deb
    echo -e "[${g}Info${p}] 更新成功！"
  else
    echo -e "| ${y}xray+caddy${p}  | ${g}${local_version}${p}"
  fi
  exit 0
}

uninstall_xray() {
  echo -e "[${g}Info${p}] 正在卸载${y}xray${p}..."
  dpkg --purge xray
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_xray() {
  uuid=$(awk -F'"' '/id:/ {print$2}' /usr/local/etc/xray/config.yaml | head -n1)
  domain=$(awk 'NR==1 {print$1}' /usr/local/etc/caddy/Caddyfile)
  xraystatus=$(pgrep xray)
  caddystatus=$(pgrep caddy)
  echo
  [ -z "$xraystatus" ] && echo -e " xray运行状态：${r}已停止${p}" || echo -e " xray运行状态：${g}正在运行${p}"
  [ -z "$caddystatus" ] && echo -e " caddy运行状态：${r}已停止${p}" || echo -e " caddy运行状态：${g}正在运行${p}"
  echo
  echo -e " 分享码 (grpc)："
  echo -e " ${r}vless://${uuid}@${domain}:443?type=grpc&encryption=none&security=tls&serviceName=grpc#grpc${p}"
  echo
  echo -e " uuid:"
  echo -e " ${y}$(xray uuid -i "$uuid")${p}"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install)
    install_xray
    ;;
  -i)
    info_xray
    ;;
  -u)
    uninstall_xray
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|-u uninstall|-i info]"
    ;;
esac
