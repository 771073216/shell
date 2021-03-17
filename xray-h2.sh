#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
TMP_DIR="$(mktemp -du)"
uuid=$(cat /proc/sys/kernel/random/uuid)
[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
link=https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip

check_xray() {
  if command -v "xray" > /dev/null 2>&1; then
    update_xray
  fi
}

pre_install() {
  wget "https://cdn.jsdelivr.net/gh/771073216/azzb@master/github" -O '/var/www/index.html'
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  echo -e -n "[${g}Info${p}] 输入path： "
  read -r path
}

set_xray() {
  install -d /usr/local/etc/xray/
  set_conf
  set_bbr
  set_service
}

set_conf() {
  cat > /usr/local/etc/xray/config.json <<- EOF
{
  "inbounds": [
    {
      "port": 2001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "security": "none",
        "network": "h2",
        "httpSettings": {
          "path": "/${path}",
          "host": [
            "${domain}"
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
  cat > /etc/caddy/Caddyfile <<- EOF
${domain} {
    root * /var/www
    file_server
    reverse_proxy /$path 127.0.0.1:2001 {
        transport http {
            versions h2c
        }
    }
}
EOF
}

set_bbr() {
  echo -e "[${g}Info${p}] 设置bbr..."
  sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
  sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
  (echo "net.core.default_qdisc = fq" && echo "net.ipv4.tcp_congestion_control = bbr") >> '/etc/sysctl.conf'
  sysctl -p > /dev/null 2>&1
}

set_service(){
cat > /etc/systemd/system/xray.service <<- EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
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
  wget -q --show-progress https://api.azzb.workers.dev/"$link"
  unzip -oq "Xray-linux-64.zip" "xray" -d ./
  mv "xray" /usr/local/bin/
}

update_xray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  ver=$(wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  ver1=v$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  verc=$(echo "$ver" | tr -d .v)
  ver1c=$(echo "$ver1" | tr -d .v)
  if [ "${ver1c}" -gt "${verc}" ]; then
    echo -e "[${g}Info${p}] ${y}xray${p}已安装pre版本${g}${ver1}${p}。"
  elif [ "${ver1c}" -eq "${verc}" ]; then
    echo -e "[${g}Info${p}] ${y}xray${p}已安装最新版本${g}${ver1}${p}。"
  else
    echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}${ver1}${p} --> ${g}${ver}${p}"
    install_file
    systemctl restart xray
    echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

install_xray() {
  check_xray
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  pre_install
  install_caddy
  install_file
  rm -rf "$TMP_DIR"
  set_xray
  systemctl enable xray --now
  info_xray
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
  domain=$(awk -F'"' 'NR==21 {print$2}' /usr/local/etc/xray/config.json)
  uuid=$(awk -F'"' 'NR==10 {print$4}' /usr/local/etc/xray/config.json)
  path=$(awk -F'"' 'NR==19 {print$4}' /usr/local/etc/xray/config.json | tr -d /)
  status=$(pgrep -a xray | grep -c xray)
  [ ! -f /usr/local/etc/xray/config.json ] && echo -e "[${r}Error${p}] 未找到xray配置文件！" && exit 1
  [ "$status" -eq 0 ] && xraystatus="${r}已停止${p}" || xraystatus="${g}正在运行${p}"
  echo -e " 分享码： ${y}vless://$uuid@$domain:2001?encryption=none&security=tls&type=http&host=$domain&path=$path${p}"
  echo -e " xray运行状态：${xraystatus}"
}

manual() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  ver=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/tags | awk -F '"' '/name/ {print $4}' | head -n 1)
  echo "$ver"
  echo "correct?  q = quit "
  read -r co
  if ! [ "$co" = q ]; then
    link=https://github.com/XTLS/Xray-core/releases/download/$ver/Xray-linux-64.zip
    install_file
    systemctl daemon-reload
    systemctl restart xray
  else
    echo "cancel"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | info | uninstall)
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
