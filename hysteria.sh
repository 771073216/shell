#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1

set_conf() {
  cat > /usr/local/etc/hysteria/config.yaml <<- EOF
listen: :8443

acme:
  domains:
     - www.example.com
  email: your@email.com 
  disableTLSALPN: true
  ca: zerossl  

auth:
  type: password
  password: password

acl:
  inline: 
    - reject(all, udp/443)
    - reject(geoip:cn)
  geoip: geoip.dat

EOF
}

set_service() {
  cat > /etc/systemd/system/hysteria.service <<- EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
Group=root
WorkingDirectory=/usr/local/share/hysteria
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/hysteria server -c /usr/local/etc/hysteria_config.yaml --log-level info
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

install_hysteria() {
  if command -v hysteria; then
    update_hysteria
    exit 0
  fi
  mkdir -p /usr/local/etc/hysteria/ /usr/local/share/hysteria/
  set_service
  set_conf
  wget -q --show-progress https://github.com/HyNetwork/hysteria/releases/latest/download/hysteria-linux-amd64 -O /usr/local/bin/hysteria
  chmod +x /usr/local/bin/hysteria
}

update_hysteria() {
  latest_version=$(wget -qO- https://api.github.com/repos/HyNetwork/hysteria/releases/latest | awk -F '"' '/tag_name/ {print $4}')
  local_version=$(/usr/local/bin/hysteria version | awk '/Version/{print "app/"$2}')
  [ "$latest_version" == "$local_version" ] && echo "no update" && exit 0
  wget -q --show-progress https://github.com/HyNetwork/hysteria/releases/latest/download/hysteria-linux-amd64 -O /usr/local/bin/hysteria
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

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | uninstall)
    "${action}"_hysteria
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall]"
    ;;
esac
