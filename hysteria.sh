#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
ssl_dir=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

port_hopping() {
  if ! command -v iptables-persistent > /dev/null; then
    apt install iptables-persistent
  fi
  echo -e -n "[${g}Info${p}] 输入端口区间：(eg.11111-22222)"
  read -r hopping_ports
  iptables -t nat -A PREROUTING -i eth0 -p udp --dport "$hopping_ports" -j DNAT --to-destination :"$port"
  netfilter-persistent save
}

check_port() {
  if ! command -v lsof > /dev/null; then
    apt install lsof
  fi
  port_status=$(lsof -i :80)
  [ -n "$port_status" ] && echo "port 80 is used" && exit 1
}

set_conf1() {
  cat > /usr/local/etc/hysteria/config.json <<- EOF
{
  "protocol": "udp",
  "listen": ":$port",
  "acme": {
    "domains": [
      "$domain"
    ],
    "email": "email@gmail.com"
  },
  "alpn": "h3",
  "acl": "/usr/local/share/hysteria/block_http3.acl",
  "obfs": "$passwd"
}
EOF
}

set_conf2() {
  cat > /usr/local/etc/hysteria/config.json <<- EOF
{
    "protocol": "udp",
    "listen": ":$port",
    "cert": "/usr/local/share/hysteria/fullchain.cer",
    "key": "/usr/local/sahre/hysteria/private.key",
    "alpn": "h3",
    "acl": "/usr/local/share/hysteria/block_http3.acl",
    "obfs": "$passwd"
}
EOF
  cp $ssl_dir/"${domain}"/"${domain}".crt /usr/local/share/hysteria/fullchain.cer
  cp $ssl_dir/"${domain}"/"${domain}".key /usr/local/share/hysteria/private.key
}

copy_ca() {
  cat > /usr/local/share/hysteria/update.sh <<- EOF
#!/bin/bash
dir="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/"
cer="\${dir}${domain}/${domain}.crt"
key="\${dir}${domain}/${domain}.key"
renew_time=\$(stat -c %Y \$cer)
if [ -e "/root/hysteria/renew" ]; then
  local_time=\$(cat /root/hysteria/renew)
  if [ "\$renew_time" != "\$local_time" ]; then
    echo "updating"
    rm /root/hysteria/fullchain.cer /root/hysteria/private.key
    cp \$cer /root/hysteria/fullchain.cer
    cp \$key /root/hysteria/private.key
    echo "\$renew_time" > /root/hysteria/renew
        echo "done"
  fi
else
  echo "\$renew_time" > /root/hysteria/renew
fi
EOF
  chmod +x /usr/local/share/hysteria/update.sh
  crontab -l | grep -v "0 0 \* \* 1 bash /usr/local/share/hysteria/update.sh" | crontab
  (
    crontab -l
    echo "0 0 * * 1 bash /usr/local/share/hysteria/update.sh"
  ) | crontab
}

set_service() {
  cat > /etc/systemd/system/hysteria.service <<- EOF
[Unit]
After=network.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/hysteria server -c /usr/local/etc/hysteria/config.json --log-level info
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
}

install_hysteria() {
  if [ -f /etc/systemd/system/hysteria.service ]; then
    update_hysteria
    exit 0
  fi
  check_port
  echo -e -n "[${g}Info${p}] get ssl (1/auto 2/mamul):"
  read -r select
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  echo -e -n "[${g}Info${p}] 输入端口： "
  read -r port
  echo -e -n "[${g}Info${p}] 输入混淆密码： "
  read -r passwd
  echo -e -n "[${g}Info${p}] 开启端口跳跃？ (y/n)"
  read -r ishopping
  mkdir -p /usr/local/etc/hysteria/ /usr/local/share/hysteria/
  set_service
  if [ "$select" -eq 1 ]; then
    set_conf1
  else
    set_conf2
  fi
  if [ "$ishopping" == "y" ]; then
    port_hopping
  fi
  wget -q --show-progress https://github.com/HyNetwork/hysteria/releases/latest/download/hysteria-linux-amd64 -O /usr/local/bin/hysteria
  chmod +x /usr/local/bin/hysteria
  systemctl enable hysteria --now
  info_hysteria
}

update_hysteria() {
  latest_version=$(wget -qO- https://api.github.com/repos/HyNetwork/hysteria/releases/latest | awk -F '"' '/tag_name/ {print $4}' | tr -d v)
  local_version=$(/usr/local/bin/hysteria -v | awk '{print$3}' | tr -d v)
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
  crontab -l | grep -v "0 0 \* \* 1 bash /usr/local/share/hysteria/update.sh" | crontab
  iptables -t nat -D PREROUTING 1
  netfilter-persistent save
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_hysteria() {
  status=$(pgrep hysteria)
  [ ! -f /usr/local/etc/hysteria/config.json ] && echo -e "[${r}Error${p}] 未找到hysteria配置文件！" && exit 1
  [ -z "$status" ] && hysteria_status="${r}已停止${p}" || hysteria_status="${g}正在运行${p}"
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
