#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
rm -rf /tmp/xray && mkdir /tmp/xray

install_xray() {
  uuid=$(cat /proc/sys/kernel/random/uuid)
  [ -f /usr/local/bin/xray ] && update_xray
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/xray.deb -O /tmp/xray/xray.deb
  dpkg -i /tmp/xray/xray.deb && rm -rf /tmp/xray
  sed -i "s/uuid/$uuid/g" /usr/local/etc/xray/config.yaml
  sed -i "1c$domain {" /usr/local/etc/caddy/Caddyfile
  systemctl restart xray caddy
  info_xray
}

update_xray() {
  wget -q "https://cdn.jsdelivr.net/gh/771073216/dist@main/version" -O /tmp/xray/verison
  xray_remote=$(awk '/xray/ {print$2}' /tmp/xray/version)
  caddy_remote=$(awk '/caddy/ {print$2}' /tmp/xray/version)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}' | tr -d v)
  remote_num=$(echo "$xray_remote" | tr -d .)
  local_num=$(echo "$xray_local" | tr -d .)
  if [ "${local_num}" -lt "${remote_num}" ]; then
    echo -e "| ${y}xray${p}  | ${r}v${xray_local}${p} --> ${g}v${xray_remote}${p}"
    update="1"
  else
    echo -e "| ${y}xray${p}  | ${g}v${xray_local}${p}"
  fi
  if ! [ "${caddy_local}" == "${caddy_remote}" ]; then
    echo -e "| ${y}caddy${p} | ${r}v${caddy_local}${p} --> ${g}v${caddy_remote}${p}"
    update="1"
  else
    echo -e "| ${y}caddy${p} | ${g}v${caddy_local}${p}"
  fi
  if [ "${update}" -eq 1 ]; then
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/xray.deb -O /tmp/xray/xray.deb
    dpkg -i /tmp/xray/xray.deb && rm -rf /tmp/xray
    echo -e "[${g}Info${p}] 更新成功！"
  fi
  exit 0
}

uninstall_xray() {
  echo -e "[${g}Info${p}] 正在卸载${y}xray${p}..."
  dpkg --purge xray
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_xray() {
  uuid=$(awk -F'"' '/id:/ {print$2}' /usr/local/etc/xray/config.yaml)
  xraystatus=$(pgrep -a xray | grep -c xray)
  caddystatus=$(pgrep -a caddy | grep -c caddy)
  echo
  [ "$xraystatus" -eq 0 ] && echo -e " xray运行状态：${r}已停止${p}" || echo -e " xray运行状态：${g}正在运行${p}"
  [ "$caddystatus" -eq 0 ] && echo -e " caddy运行状态：${r}已停止${p}" || echo -e " caddy运行状态：${g}正在运行${p}"
  echo
  echo -e " 分享码："
  echo -e " ${r}vless://${uuid}@${domain}:443?type=grpc&encryption=none&security=tls&serviceName=grpc#grpc${p}"
  echo
  echo -e "(windows)v2rayN下载链接：${g}https://cdn.jsdelivr.net/gh/771073216/dist@main/v2rayn-core.zip${p}"
  echo -e "(android)v2rayNG下载链接：${g}https://cdn.jsdelivr.net/gh/771073216/dist@main/v2rayng.apk${p}"
}

manual() {
  ver=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/tags | awk -F '"' '/name/ {print $4}' | head -n 1)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}v${xray_local}${p} --> ${g}${ver}${p}"
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/download/"$ver"/Xray-linux-64.zip -O /tmp/xray/xray.zip
  unzip -oq "/tmp/xray/xray.zip" xray -d /usr/local/bin/ && rm -rf /tmp/xray
  systemctl restart xray
  echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | info | uninstall)
    ${action}_xray
    ;;
  -m)
    manual
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall|info|-m]"
    ;;
esac
