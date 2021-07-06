#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
TMP_DIR="$(mktemp -du)"

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1

update_xray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  wget -q "https://cdn.jsdelivr.net/gh/771073216/dist@main/version"
  xray_remote=$(awk '/^xray/ {print$2}' version)
  caddy_remote=$(awk '/caddy/ {print$2}' version)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}' | tr -d v)
  remote_num=$(echo "$xray_remote" | tr -d .)
  local_num=$(echo "$xray_local" | tr -d .)
  if [ "${local_num}" -lt "${remote_num}" ]; then
    echo -e "| ${y}xray${p} | ${r}v${xray_local}${p} --> ${g}v${xray_remote}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/linux/xray-linux.zip
    unzip -oq "xray-linux.zip" xray -d /usr/local/bin/
    systemctl restart xray
    echo -e "| ${y}xray${p} | ${g}更新成功！${p}"
  else
    echo -e "| ${y}xray${p} | ${g}v${xray_local}${p}"
  fi
  if ! [ "${caddy_local}" == "${caddy_remote}" ]; then
    echo -e "| ${y}caddy${p} | ${r}v${caddy_local}${p} --> ${g}v${caddy_remote}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/linux/caddy.deb
    dpkg -i caddy.deb
    echo -e "| ${y}caddy${p} | ${g}更新成功！${p}"
  else
    echo -e "| ${y}caddy${p} | ${g}v${caddy_local}${p}"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

uninstall_xray() {
  echo -e "[${g}Info${p}] 正在卸载${y}xray${p}..."
  systemctl disable xray --now
  rm -f /usr/local/bin/xray
  rm -rf /usr/local/etc/xray/
  rm -f /etc/systemd/system/xray.service
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_xray() {
  uuid=$(awk -F'"' '/id:/ {print$2}' /usr/local/etc/xray/config.yaml)
  domain=$(awk 'NR==1 {print$1}' /etc/caddy/Caddyfile)
  xraystatus=$(pgrep -a xray | grep -c xray)
  caddystatus=$(pgrep -a caddy | grep -c caddy)
  echo
  [ "$xraystatus" -eq 0 ] && echo -e "| ${y}xray${p} | ${r}已停止${p}" || echo -e "| ${y}xray${p} | ${g}正在运行${p}"
  [ "$caddystatus" -eq 0 ] && echo -e "| ${y}caddy${p} | ${r}已停止${p}" || echo -e "| ${y}caddy${p} | ${g}正在运行${p}"
  echo
  echo -e " 分享码："
  echo -e " ${r}vless://${uuid}@${domain}:443?type=grpc&encryption=none&security=tls&serviceName=grpc#grpc${p}"
}

manual() {
  ver=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/tags | awk -F '"' '/name/ {print $4}' | head -n 1)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  echo -e "| ${y}xray${p} | ${r}v${xray_local}${p} --> ${g}${ver}${p}"
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/download/"$ver"/Xray-linux-64.zip
  unzip -oq "Xray-linux-64.zip" xray -d /usr/local/bin/
  rm -rf "$TMP_DIR"
  systemctl restart xray
  echo -e "| ${y}xray${p} | ${y}xray${p}更新成功！"
}

action=$1
[ -z "$1" ] && action=update
case "$action" in
  update | info | uninstall)
    ${action}_xray
    ;;
  -m)
    manual
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [update|uninstall|info|-m]"
    ;;
esac
