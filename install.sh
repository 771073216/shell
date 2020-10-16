#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

TMP_DIR="$(mktemp -du)"
uuid=$(cat /proc/sys/kernel/random/uuid)
v2link=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
tsplink=https://github.com/liberal-boy/tls-shunt-proxy/releases/latest/download/tls-shunt-proxy-linux-amd64.zip

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

check_install() {
  if command -v "v2ray" > /dev/null 2>&1; then
    update_v2ray
  else
    install_v2
    config_v2ray
  fi
  if command -v "tls-shunt-proxy" > /dev/null 2>&1; then
    update_tsp
  else
    install_tsp
    config_tsp
  fi
}

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

config_v2ray() {
  rm -rf /tmp/v2ray-ds/
  rm -rf /usr/local/etc/v2ray/
  install -d /usr/local/etc/v2ray/
  set_v2
  set_bbr
  systemctl daemon-reload
  systemctl restart v2ray
}

config_tsp() {
  install -d /etc/tls-shunt-proxy/
  wget -cq "https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip"
  unzip -oq "html.zip" -d '/var/www'
  rm -f html.zip
  IP=$(wget -4qO- icanhazip.com)
  echo -e -n "[${green}Info${plain}] 输入域名： "
  read -r domain
  [ -z "${domain}" ] && echo "[${red}Error${plain}] 未输入域名！" && exit 1
  host=$(host "${domain}")
  res=$(echo -n "${host}" | grep "${IP}")
  if [ -z "${res}" ]; then
    echo -e -n "[${green}Info${plain}] ${domain} 解析结果："
    host "${domain}"
    echo -e "[${red}Error${plain}] 主机未解析到当前服务器IP(${IP})!"
    exit 1
  fi
  set_tsp
  systemctl restart tls-shunt-proxy
}

set_v2() {
  cat > /usr/local/etc/v2ray/config.json <<- EOF
{
    "inbounds": [
        {
            "protocol": "vmess",
            "listen": "127.0.0.1",
            "port": 40001,
            "settings": {
                "clients": [
                    {
                        "id": "$uuid"
                    }
                ]
            },
            "streamSettings": {
                "network": "ds",
                "dsSettings": {
                    "path": "@v2ray.sock",
                    "abstract": true
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

set_bbr() {
  echo -e "[${green}Info${plain}] 设置bbr..."
  sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
  sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
  (echo "net.core.default_qdisc = fq" && echo "net.ipv4.tcp_congestion_control = bbr") >> '/etc/sysctl.conf'
  sysctl -p > /dev/null 2>&1
}

install_v2ray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  pre_install
  check_install
  rm -rf "$TMP_DIR"
  set_bbr
  systemctl enable v2ray
  systemctl enable tls-shunt-proxy
  info_v2ray
}

install_v2() {
  echo -e "[${green}Info${plain}] 开始安装${yellow}V2Ray${plain}"
  wget -c "https://api.azzb.workers.dev/$v2link"
  unzip -oq "v2ray-linux-64.zip"
  install -m 755 "v2ray" "v2ctl" /usr/local/bin/
  echo -e "[${green}Info${plain}] V2Ray完成安装！"
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

update_v2ray() {
  echo -e "[${green}Info${plain}] 获取${yellow}v2ray${plain}版本信息..."
  v2latest=$(wget -qO- "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  [ -z "${v2latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
  v2current=v$(/usr/local/bin/v2ray -version | awk 'NR==1 {print $2}')
  if [ "${v2latest}" == "${v2current}" ]; then
    echo -e "[${green}Info${plain}] ${yellow}V2Ray${plain}已安装最新版本${green}${v2latest}${plain}。"
  else
    echo -e "[${green}Info${plain}] 正在更新${yellow}V2Ray${plain}：${red}${v2current}${plain} --> ${green}${v2latest}${plain}"
    wget -c "https://api.azzb.workers.dev/$v2link"
    unzip -oq "v2ray-linux-64.zip"
    install -m 755 "v2ray" "v2ctl" /usr/local/bin/
    systemctl restart v2ray
    echo -e "[${green}Info${plain}] ${yellow}v2ray${plain}更新成功！"
  fi
}

update_tsp() {
  echo -e "[${green}Info${plain}] 获取${yellow}tls-shunt-proxy${plain}版本信息..."
  tsplatest=$(wget -qO- "https://api.github.com/repos/liberal-boy/tls-shunt-proxy/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  [ -z "${tsplatest}" ] && [ -z "${v2latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
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

info_v2ray() {
  status=$(pgrep -a v2ray | grep -c v2ray)
  tspstatus=$(pgrep -a tls-shunt-proxy | grep -c tls-shunt-proxy)
  [ ! -f /usr/local/etc/v2ray/config.json ] && echo -e "[${red}Error${plain}] 未找到V2Ray配置文件！" && exit 1
  [ ! -f /etc/tls-shunt-proxy/config.yaml ] && echo -e "[${red}Error${plain}] 未找到tls-shunt-proxy配置文件！" && exit 1
  [ "$status" -eq 0 ] && v2status="${red}已停止${plain}" || v2status="${green}正在运行${plain}"
  [ "$tspstatus" -eq 0 ] && tspshuntproxy="${red}已停止${plain}" || tspshuntproxy="${green}正在运行${plain}"
  echo -e " id： ${green}$(grep < '/usr/local/etc/v2ray/config.json' id | cut -d'"' -f4)${plain}"
  echo -e " v2ray运行状态：${v2status}"
  echo -e " tls-shunt-proxy运行状态：${tspshuntproxy}"
}

uninstall_v2ray() {
  echo -e "[${green}Info${plain}] 正在卸载${yellow}v2ray${plain}和${yellow}tls-shunt-proxy${plain}..."
  systemctl disable v2ray --now > /dev/null 2>&1
  systemctl disable tls-shunt-proxy --now > /dev/null 2>&1
  rm -f /usr/local/bin/v2ray
  rm -f /usr/local/bin/v2ctl
  rm -rf /usr/local/etc/v2ray/
  rm -f /etc/systemd/system/v2ray.service
  rm -f /etc/systemd/system/tls-shunt-proxy.service
  rm -f /usr/local/bin/tls-shunt-proxy
  rm -rf /etc/tls-shunt-proxy/
  rm -rf /tmp/v2ray-ds/
  echo -e "[${green}Info${plain}] 卸载成功！"
}

# Initialization step
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
