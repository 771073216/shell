#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1

check_port(){
  port_status=$(lsof -i :80)
  [ -n "$port_status" ] && echo "port 80 is used" && exit 1
}

set_conf() {
  cat > /usr/local/etc/hysteria/config.json <<- EOF
{
  "listen": ":$port",
  "acme": {
    "domains": [
      "$domain"
    ],
    "email": "email@gmail.com"
  },
  "obfs": "$passwd"
}
EOF
}

set_service() {
  cat > /etc/systemd/system/hysteria.service <<- EOF
[Unit]
Description=hysteria Service
After=network.target nss-lookup.target
[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/hysteria -config /usr/local/etc/hysteria/config.json server
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
}

install_hysteria() {
  [ -f /usr/local/bin/hysteria ] && update_hysteria
  check_port
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  echo -e -n "[${g}Info${p}] 输入端口： "
  read -r port
  echo -e -n "[${g}Info${p}] 输入混淆密码： "
  read -r passwd
  mkdir -p /usr/local/etc/hysteria/
  set_service
  set_conf
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/linux/hysteria -O /usr/local/bin/hysteria
  chmod +x /usr/local/bin/hysteria
  sysctl -w net.core.rmem_max=2500000
  systemctl enable hysteria --now
  info_hysteria
}

update_hysteria() {
  latest_version=$(wget -qO- https://cdn.jsdelivr.net/gh/771073216/dist@main/version | awk '/hysteria/ {print$2}')
  local_version=$(/usr/local/bin/hysteria -v | awk '{print$3}' | tr -d v)
  [ "$latest_version" == "$local_version" ] && echo "no update" && exit 0
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/linux/hysteria -O /usr/local/bin/hysteria
  systemctl restart hysteria
}

uninstall_hysteria() {
  echo -e "[${g}Info${p}] 正在卸载${y}hysteria${p}..."
  systemctl disable hysteria --now
  rm -f /usr/local/bin/hysteria
  rm -rf /usr/local/etc/hysteria/
  rm -f /etc/systemd/system/hysteria.service
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_hysteria() {
  status=$(pgrep hysteria)
  [ ! -f /usr/local/etc/hysteria/config.json ] && echo -e "[${r}Error${p}] 未找到hysteria配置文件！" && exit 1
  [ -z "$status" ] && hysteria_status="${r}已停止${p}" || hysteria_status="${g}正在运行${p}"
  echo -e " port： $(awk -F'[":]+' '/listen/ {print$4}' /usr/local/etc/hysteria/config.json)"
  echo -e " password： $(awk -F'"' '/obfs/ {print$4}' /usr/local/etc/hysteria/config.json)"
  echo -e " hysteria运行状态：${hysteria_status}"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | info | uninstall)
    ${action}_hysteria
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|info|uninstall]"
    ;;
esac
