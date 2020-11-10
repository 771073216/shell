#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
plain='\033[0m'
uuid=$(cat /proc/sys/kernel/random/uuid)
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1
ssl_dir=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

pre_install(){
  wget -c "https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip"
  unzip -oq "html.zip" -d '/var/www'
  echo -e -n "[${green}Info${plain}] 输入域名： "
  read -r domain
}

set_v2ray() {
  install -d /usr/local/etc/v2ray/
  set_v2
  set_bbr
  set_ssl
  set_cron
}

set_v2() {
  cat > /etc/v2ray/config.json <<- EOF
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
                            "certificateFile": "/etc/ssl/v2ray/${domain}.crt",
                            "keyFile": "/etc/ssl/v2ray/${domain}.key"
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
  install -d -o nobody -g nogroup /etc/ssl/v2ray/
  install -m 644 -o nobody -g nogroup $ssl_dir/"${domain}"/"${domain}".crt -t /etc/ssl/v2ray/
  install -m 600 -o nobody -g nogroup $ssl_dir/"${domain}"/"${domain}".key -t /etc/ssl/v2ray/
}

set_cron() {
  cat > /etc/cron.monthly/ssl <<- EOF
#!/bin/sh
install -m 644 -o nobody -g nogroup $ssl_dir/${domain}/${domain}.crt -t /etc/ssl/v2ray/
install -m 600 -o nobody -g nogroup $ssl_dir/${domain}/${domain}.key -t /etc/ssl/v2ray/
systemctl restart v2ray
EOF
}

install_file() {
  if ! command -v "caddy" > /dev/null 2>&1; then
    echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" > /etc/apt/sources.list.d/caddy-fury.list
  fi
  if ! command -v "v2ray" > /dev/null 2>&1; then
    curl -sSL https://apt.v2fly.org/pubkey.gpg | sudo apt-key add -
    echo "deb [arch=amd64] https://apt.v2fly.org/ stable main" | sudo tee /etc/apt/sources.list.d/v2ray.list
  fi
  apt update
  apt install caddy v2ray -y
  set_caddy
  systemctl restart caddy
  set_v2ray
  systemctl restart v2ray
}



install_v2ray() {
  pre_install
  install_file
  info_v2ray
}

info_v2ray() {
  status=$(pgrep -a v2ray | grep -c v2ray)
  [ ! -f /etc/v2ray/config.json ] && echo -e "[${red}Error${plain}] 未找到V2Ray配置文件！" && exit 1
  [ "$status" -eq 0 ] && v2status="${red}已停止${plain}" || v2status="${green}正在运行${plain}"
  echo -e " id： ${green}$(grep < '/etc/v2ray/config.json' id | cut -d'"' -f4)${plain}"
  echo -e " v2ray运行状态：${v2status}"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | info)
    ${action}_v2ray
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|info]"
    ;;
esac
