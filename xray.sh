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
  curl -L https://raw.githubusercontent.com/771073216/deb/main/xray.deb -o xray.deb
  dpkg -i xray.deb && rm xray.deb
  private_key=$(xray x25519 | awk '{print$3}' | head -n 1)
  sed -i "s/passwd/$passwd/g" /usr/local/etc/xray/config.yaml
  sed -i "s/private_key/$private_key/g" /usr/local/etc/xray/config.yaml
  sed -i "s/example.com/$domain/g" /usr/local/etc/xray/config.yaml
  systemctl restart xray
  state_xray
  info_xray
}

update_xray() {
  remote_version=$(curl -sSL "https://raw.githubusercontent.com/771073216/deb/main/version" | awk '/xray/{print$2}')
  local_version=$(dpkg -s xray | awk '/Version/ {print$2}')
  if ! [ "${remote_version}" == "${local_version}" ]; then
    echo -e "| ${y}xray${p}  | ${r}${local_version}${p} --> ${g}${remote_version}${p}"
    curl -L https://raw.githubusercontent.com/771073216/deb/main/xray.deb -o xray.deb
    dpkg -i --force-confold xray.deb && rm xray.deb
    echo
    echo -e "[${g}Info${p}] 更新成功！"
    state_xray
  else
    echo -e "| ${y}xray${p}  | ${g}${local_version}${p}  (latest)"
  fi
  exit 0
}

uninstall_xray() {
  echo -e "[${g}Info${p}] 正在卸载${y}xray${p}..."
  dpkg --purge xray
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_xray() {
  password=$(awk -F'"' '/id:/ {print$2}' /usr/local/etc/xray/config.yaml)
  privatekey=$(awk -F'"' '/privateKey:/ {print$2}' /usr/local/etc/xray/config.yaml)
  domain=$(awk '/dest:/ {print$2}' /usr/local/etc/xray/config.yaml)
  publickey=$(xray x25519 -i "$privatekey" | awk '{print$3}' | tail -n 1)
  echo -e "[password] ${g}$password${p}"
  echo -e "[publickey] ${g}$publickey${p}"
  echo -e "[domain] ${g}$domain${p}"
  echo -e " 分享码 ："
  echo -e " ${r}vless://${password}@${domain}:443?type=grpc&security=reality&serviceName=grpc&pbk=${publickey}&mode=gun#reality${p}"
}

state_xray() {
  xraystatus=$(pgrep xray)
  echo
  [ -z "$xraystatus" ] && echo -e " xray运行状态：${r}已停止${p}" || echo -e " xray运行状态：${g}正在运行${p}"
  echo
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
