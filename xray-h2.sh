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
  xray_remote=$(awk '/xray/ {print$2}' version)
  caddy_remote=$(awk '/caddy/ {print$2}' version)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}' | tr -d v)
  remote_num=$(echo "$xray_remote" | tr -d .)
  local_num=$(echo "$xray_local" | tr -d .)
  if [ "${local_num}" -lt "${remote_num}" ]; then
    echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}v${xray_local}${p} --> ${g}v${xray_remote}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/xray-linux.zip
    unzip -oq "xray-linux.zip" xray -d /usr/local/bin/
    systemctl restart xray
    echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
  fi
  if ! [ "${caddy_local}" == "${caddy_remote}" ]; then
    echo -e "[${g}Info${p}] 正在更新${y}caddy${p}：${r}v${caddy_local}${p} --> ${g}v${caddy_remote}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/caddy.deb
    dpkg -i caddy.deb
    echo -e "[${g}Info${p}] ${y}caddy${p}更新成功！"
  fi
  if [ "${local_num}" -gt "${remote_num}" ]; then
    echo -e "[${g}Info${p}] ${y}xray${p}已安装pre版本${g}${xray_local}${p}。"
  else
    echo -e "[${g}Info${p}] ${y}xray${p}已安装最新版本${g}${xray_remote}${p}。"
  fi
  echo -e "[${g}Info${p}] ${y}caddy${p}已安装最新版本${g}${caddy_remote}${p}。"
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
  [ "$xraystatus" -eq 0 ] && echo -e " xray运行状态：${r}已停止${p}" || echo -e " xray运行状态：${g}正在运行${p}"
  [ "$caddystatus" -eq 0 ] && echo -e " caddy运行状态：${r}已停止${p}" || echo -e " caddy运行状态：${g}正在运行${p}"
  echo
  echo -e " 分享码："
  echo -e " ${r}vless://${uuid}@${domain}:443?type=grpc&encryption=none&security=tls&serviceName=grpc#grpc${p}"
}

manual() {
  ver=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/tags | awk -F '"' '/name/ {print $4}' | head -n 1)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}v${xray_local}${p} --> ${g}${ver}${p}"
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/download/"$ver"/Xray-linux-64.zip
  unzip -oq "Xray-linux-64.zip" xray -d /usr/local/bin/
  rm -rf "$TMP_DIR"
  systemctl restart xray
  echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  update | info | uninstall)
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
