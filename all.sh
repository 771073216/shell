#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
uuid=$(cat /proc/sys/kernel/random/uuid)
tsplink=https://github.com/liberal-boy/tls-shunt-proxy/releases/latest/download/tls-shunt-proxy-linux-amd64.zip
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

pre_install() {
  if ! command -v "unzip" > /dev/null 2>&1; then
    echo -e "[${green}Info${plain}] 正在安装unzip..."
    if command -v "apt" > /dev/null 2>&1; then
      apt -y install unzip
    else
      yum -y install unzip
    fi
  fi
}

chore() {
  wget -c "https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip"
  unzip -oq "html.zip" -d '/var/www'
}

check_install() {
  if ! command -v "v2ray" > /dev/null 2>&1; then
    install_v2
  fi
  if command -v "tls-shunt-proxy" > /dev/null 2>&1; then
    update_tsp
  fi
}

set_config() {
  cat > /etc/v2ray/config.json <<- EOF
{
    "inbounds": [
        {
            "protocol": "vless",
            "listen": "127.0.0.1",
            "port": $port,
            "settings": {
                "decryption": "none",
                "clients": [
                    {
                        "id": "$uuid"
                    }
                ]
            },
            "streamSettings": {
                "security": "$tls",
                "network": "$type",
                "httpSettings": {"path": "/${h2path}","host": ["${domain}"]}
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

choice() {
  echo -e "1.vmess+tsp 2.vmess+h2c 3.vless+tsp 4.vless+h2c"
  echo -e -n "[${green}Info${plain}] 输入： "
  read -r selected
}

install_v2() {
  curl -sSL https://apt.v2fly.org/pubkey.gpg | sudo apt-key add -
  echo "deb [arch=amd64] https://apt.v2fly.org/ stable main" | sudo tee /etc/apt/sources.list.d/v2ray.list
  apt update
  apt install v2ray -y
}

install_tsp() {
  echo -e "[${green}Info${plain}] 开始安装${yellow}tls-shunt-proxy${plain}"
  wget -c "https://api.azzb.workers.dev/$tsplink"
  wget -qP /etc/systemd/system/ 'https://cdn.jsdelivr.net/gh/liberal-boy/tls-shunt-proxy@master/dist/tls-shunt-proxy.service'
  unzip -oq "tls-shunt-proxy-linux-amd64.zip"
  install -m 755 "tls-shunt-proxy" /usr/local/bin/
  if ! grep < /etc/passwd tls-shunt-proxy; then
    useradd tls-shunt-proxy -s /usr/sbin/nologin
  fi
  install -d -o tls-shunt-proxy -g tls-shunt-proxy /etc/ssl/tls-shunt-proxy/
  echo -e "[${green}Info${plain}] tls-shunt-proxy完成安装！"
}

install_caddy() {
  if ! command -v "caddy" > /dev/null 2>&1; then
    echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" > /etc/apt/sources.list.d/caddy-fury.list
    apt update && apt install caddy
  fi
}

set_tsp() {
  cat > /etc/tls-shunt-proxy/config.yaml <<- EOF
listen: 0.0.0.0:443
redirecthttps: 0.0.0.0:80
inboundbuffersize: 4
outboundbuffersize: 32
vhosts:
  - name: $domain
    tlsoffloading: true
    managedcert: true
    alpn: h2
    protocols: tls13
    http:
      handler: fileServer
      args: /var/www
    default:
      handler: proxyPass
      args: unix:@v2ray.sock
EOF
}

set_caddy() {
  cat > /etc/caddy/Caddyfile <<- EOF
${domain} {
  root * /var/www
  file_server
  reverse_proxy /${h2path} 127.0.0.1:2001 {
    transport http {
      versions h2c
    }
  }
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

update_tsp() {
  echo -e "[${green}Info${plain}] 获取${yellow}tls-shunt-proxy${plain}版本信息..."
  tsplatest=$(wget -qO- "https://api.github.com/repos/liberal-boy/tls-shunt-proxy/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  [ -z "${tsplatest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
  tspcurrent=$(/usr/local/bin/tls-shunt-proxy 2>&1 | awk 'NR==1 {print $3}')
  if [ "${tsplatest}" == "${tspcurrent}" ]; then
    echo -e "[${green}Info${plain}] ${yellow}tls-shunt-proxy${plain}已安装最新版本${green}${tsplatest}${plain}。"
  else
    echo -e "[${green}Info${plain}] 正在更新${yellow}tls-shunt-proxy${plain}：${red}${tspcurrent}${plain} --> ${green}${tsplatest}${plain}"
    wget -c "https://api.azzb.workers.dev/$tsplink"
    unzip -oq "tls-shunt-proxy-linux-amd64.zip"
    install -m 755 "tls-shunt-proxy" /usr/local/bin/
    systemctl restart tls-shunt-proxy
    echo -e "[${green}Info${plain}] ${yellow}tls-shunt-proxy${plain}更新成功！"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

vmess_change() {
  sed -i '/decryption/d' '/etc/v2ray/config.json'
  sed -i 's/vless/vmess/g' '/etc/v2ray/config.json'
}

set_h2c() {
  port=2001
  tls=tls
  type=tcp
  echo -e -n "[${green}Info${plain}] 输入域名： "
  read -r domain
  echo -e -n "[${green}Info${plain}] 输入path： "
  read -r h2path
  set_caddy
  set_config
  systemctl restart v2ray caddy
}

set_tsp() {
  port=40001
  tls=tls
  type=tcp
  echo -e -n "[${green}Info${plain}] 输入域名： "
  read -r domain
  set_tsp
  set_config
  sed -i '/httpSettings/d' '/etc/v2ray/config.json'
  systemctl enable tls-shunt-proxy --now
  systemctl restart v2ray
}

install_v2ray() {
  pre_install
  check_install
  choice
  if [ "${selected}" == '1' ]; then
    install_tsp
    set_tsp
    vmess_change
  elif [ "${selected}" == '2' ]; then
    install_caddy
    set_h2c
    vmess_change
  elif [ "${selected}" == '3' ]; then
    install_tsp
    set_tsp
  elif [ "${selected}" == '4' ]; then
    install_caddy
    set_h2c
  fi
  chore
  set_bbr
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | uninstall | info)
    ${action}_v2ray
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall|info]"
    ;;
esac
