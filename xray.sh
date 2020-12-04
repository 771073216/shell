#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
uuid=$(cat /proc/sys/kernel/random/uuid)
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1
ssl_dir=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

check_v2() {
  if command -v "xray" > /dev/null 2>&1; then
    update_xray
  fi
}

pre_install() {
  wget -c "https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip"
  unzip -oq "html.zip" -d '/var/www'
  echo -e -n "[${green}Info${plain}] 输入域名： "
  read -r domain
}

set_xray() {
  install -d /usr/local/etc/xray/
  set_v2
  set_bbr
  set_ssl
  set_cron
}

set_v2() {
  cat > /etc/xray/config.json <<- EOF
{
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "/etc/ssl/xray/${domain}.crt",
                            "keyFile": "/etc/ssl/xray/${domain}.key"
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

set_caddy() {
  cat > /etc/caddy/caddyfile <<- EOF
${domain}:80 {
    root * /var/www
    file_server
}
EOF
}

set_bbr() {
  echo -e "[${green}Info${plain}] 设置bbr..."
  sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
  sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
  (echo "net.core.default_qdisc = fq" && echo "net.ipv4.tcp_congestion_control = bbr") >> '/etc/sysctl.conf'
  sysctl -p > /dev/null 2>&1
}

set_ssl() {
  install -d -o nobody -g nogroup /etc/ssl/xray/
  install -m 644 -o nobody -g nogroup $ssl_dir/"${domain}"/"${domain}".crt -t /etc/ssl/xray/
  install -m 600 -o nobody -g nogroup $ssl_dir/"${domain}"/"${domain}".key -t /etc/ssl/xray/
}

set_cron() {
  cat > /etc/cron.monthly/ssl <<- EOF
#!/bin/sh
install -m 644 -o nobody -g nogroup $ssl_dir/${domain}/${domain}.crt -t /etc/ssl/xray/
install -m 600 -o nobody -g nogroup $ssl_dir/${domain}/${domain}.key -t /etc/ssl/xray/
systemctl restart xray
EOF
}

install_caddy() {
  if ! command -v "caddy" > /dev/null 2>&1; then
    echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" > /etc/apt/sources.list.d/caddy-fury.list
    apt update
    apt install caddy
  fi
  set_caddy
  systemctl restart caddy
}

install_file() {
  wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  unzip -oq "Xray-linux-64.zip"
  install -m 755 "xray" /usr/local/bin/
  install -m 644 "xray.service" /etc/systemd/system/
}

update_xray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  v2latest=$(wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  v2current=v$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  if [ "${v2latest}" == "${v2current}" ]; then
    echo -e "[${green}Info${plain}] ${yellow}xray${plain}已安装最新版本${green}${v2latest}${plain}。"
  else
    echo -e "[${green}Info${plain}] 正在更新${yellow}xray${plain}：${red}${v2current}${plain} --> ${green}${v2latest}${plain}"
    install_file
    systemctl daemon-reload
    systemctl restart xray
    echo -e "[${green}Info${plain}] ${yellow}xray${plain}更新成功！"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

install_xray() {
  check_v2
  pre_install
  install_caddy
  install_file
  set_xray
  systemctl enable xray --now
  info_xray
}

uninstall_xray() {
  echo -e "[${green}Info${plain}] 正在卸载${yellow}xray${plain}..."
  systemctl disable xray --now
  rm -f /usr/local/bin/xray
  rm -rf /usr/local/etc/xray/
  rm -f /etc/systemd/system/xray.service
  echo -e "[${green}Info${plain}] 卸载成功！"
}

info_xray() {
  status=$(pgrep -a xray | grep -c xray)
  [ ! -f /etc/xray/config.json ] && echo -e "[${red}Error${plain}] 未找到xray配置文件！" && exit 1
  [ "$status" -eq 0 ] && v2status="${red}已停止${plain}" || v2status="${green}正在运行${plain}"
  echo -e " id： ${green}$(grep < '/etc/xray/config.json' id | cut -d'"' -f4)${plain}"
  echo -e " xray运行状态：${v2status}"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | info)
    ${action}_xray
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|info]"
    ;;
esac
