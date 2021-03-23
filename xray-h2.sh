#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
TMP_DIR="$(mktemp -du)"
h2conf=/usr/local/etc/xray/h2.json
wsconf=/usr/local/etc/xray/ws.json
grpcconf=/usr/local/etc/xray/grpc.json
[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
link=https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip

pre_install() {
  if ! command -v "wget" > /dev/null 2>&1; then
    echo -e "[${g}Info${p}] installing wget"
    apt install wget -y
  fi
  if ! command -v "unzip" > /dev/null 2>&1; then
    echo -e "[${g}Info${p}] installing unzip"
    apt install unzip -y
  fi
  install -m 755 "$(basename "$0")" /usr/local/bin/xray.sh
  wget -q --show-progress "https://cdn.jsdelivr.net/gh/771073216/azzb@master/github" -O '/var/www/index.html'
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
}

set_xray() {
  install -d /usr/local/etc/xray/
  install -d /usr/local/share/xray/
  set_conf
  set_bbr
  set_service
}

set_conf() {
  h2uuid=$(cat /proc/sys/kernel/random/uuid)
  cat > $h2conf <<- EOF
{
  "inbounds": [
    {
      "port": 2003,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "tag": "h2",
      "settings": {
        "clients": [
          {
            "id": "${h2uuid}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "security": "none",
        "network": "h2",
        "httpSettings": {
          "path": "/vlh2",
          "host": [
            "${domain}"
          ]
        }
      }
    }
  ]
}
EOF
  wsuuid=$(cat /proc/sys/kernel/random/uuid)
  cat > $wsconf <<- EOF
{
  "inbounds": [
    {
      "port": 2001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "tag": "ws",
      "settings": {
        "clients": [
          {
            "id": "${wsuuid}"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmws"
        }
      }
    }
  ]
}
EOF
  grpcuuid=$(cat /proc/sys/kernel/random/uuid)
  cat > $grpcconf <<- EOF
{
  "inbounds": [
    {
      "port": 2002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "tag": "grpc",
      "settings": {
        "clients": [
          {
            "id": "${grpcuuid}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "grpc"
        }
      }
    }
  ]
}
EOF
  cat > /usr/local/etc/xray/outbounds.json <<- EOF
{
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "blocked",
      "protocol": "blackhole"
    }
  ]
}
EOF
  cat > /usr/local/etc/xray/routing.json <<- EOF
{
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF
}

set_caddy() {
  mkdir /etc/caddy/
  cat > /etc/caddy/Caddyfile <<- EOF
${domain} {
    @ws {
        path /vmws
        header Connection *Upgrade*
        header Upgrade websocket
    }
    @grpc protocol grpc
    reverse_proxy @ws http://127.0.0.1:2001
    reverse_proxy @grpc h2c://127.0.0.1:2002
    reverse_proxy /vlh2 h2c://127.0.0.1:2003
    root * /var/www
    file_server
}
EOF
}

set_service() {
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
ExecStart=/usr/local/bin/xray run -confdir /usr/local/etc/xray/
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
}

set_bbr() {
  echo -e "[${g}Info${p}] 设置bbr..."
  sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
  sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
  (echo "net.core.default_qdisc = fq" && echo "net.ipv4.tcp_congestion_control = bbr") >> '/etc/sysctl.conf'
  sysctl -p > /dev/null 2>&1
}

install_caddy() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  caddy_remote=$(wget -qO- "https://api.github.com/repos/caddyserver/caddy/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  caddy_ver=$(echo "$caddy_remote" | tr -d v)
  wget -q --show-progress https://github.com/caddyserver/caddy/releases/download/"$caddy_remote"/caddy_"$caddy_ver"_linux_amd64.deb
  dpkg -i caddy_"$caddy_ver"_linux_amd64.deb
  rm -rf "$TMP_DIR"
}

install_file() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  wget -q --show-progress "$link"
  unzip -oq "Xray-linux-64.zip"
  mv xray /usr/local/bin/
  mv geoip.dat geosite.dat /usr/local/share/xray/
  systemctl restart xray
  rm -rf "$TMP_DIR"
}

update_xray() {
  xray_remote=$(wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  xray_local=v$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  remote_num=$(echo "$xray_remote" | tr -d .v)
  local_num=$(echo "$xray_local" | tr -d .v)
  if ! [ "${local_num}" -le "${remote_num}" ]; then
    echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}${xray_local}${p} --> ${g}${xray_remote}${p}"
    install_file
    echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
  fi
  update_caddy
}

update_caddy() {
  caddy_remote=$(wget -qO- "https://api.github.com/repos/caddyserver/caddy/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  caddy_ver=$(echo "$caddy_remote" | tr -d v)
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}')
  if ! [ "${caddy_local}" == "${caddy_remote}" ]; then
    echo -e "[${g}Info${p}] 正在更新${y}caddy${p}：${r}${caddy_local}${p} --> ${g}${caddy_remote}${p}"
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    wget -q --show-progress https://github.com/caddyserver/caddy/releases/download/"$caddy_remote"/caddy_"$caddy_ver"_linux_amd64.deb
    dpkg -i caddy_"$caddy_ver"_linux_amd64.deb
    rm -rf "$TMP_DIR"
    echo -e "[${g}Info${p}] ${y}caddy${p}更新成功！"
  fi
  if [ "${local_num}" -gt "${remote_num}" ]; then
    echo -e "[${g}Info${p}] ${y}xray${p}已安装pre版本${g}${xray_local}${p}。"
  else
    echo -e "[${g}Info${p}] ${y}xray${p}已安装最新版本${g}${xray_local}${p}。"
  fi
  echo -e "[${g}Info${p}] ${y}caddy${p}已安装最新版本${g}${caddy_local}${p}。"
  exit 0
}

set_cron() {
  echo "0 4 */3 * * /usr/local/bin/xray.sh update" | crontab -
}

install_xray() {
  [ -f /usr/local/bin/xray ] && update_xray
  pre_install
  set_xray
  set_caddy
  install_caddy
  install_file
  systemctl enable xray --now
  set_cron
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
  h2uuid=$(awk -F'"' '/"id"/ {print$4}' $h2conf)
  h2path=$(awk -F'"' '/"path"/ {print$4}' $h2conf | tr -d /)
  domain=$(grep -A 1 host $h2conf | grep -v host | awk -F'"' '{print$2}')
  status=$(pgrep -a xray | grep -c xray)
  vmlink=$(
    cat << EOF
{
  "v": "2",
  "ps": "",
  "add": "${domain}",
  "port": "443",
  "id": "${wsuuid}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "",
  "path": "vmws",
  "tls": "tls"
}
EOF
  )
  [ "$status" -eq 0 ] && xraystatus="${r}已停止${p}" || xraystatus="${g}正在运行${p}"
  echo
  echo -e " ${y}(延迟更低)${p} 分享码1："
  echo -e " ${r}vless://${h2uuid}@${domain}:443?encryption=none&security=tls&type=http&host=${domain}&path=${h2path}${p}"
  echo
  echo -e " ${y}(ios专用)${p} 分享码2："
  echo -e " ${r}vmess://$(echo "$vmlink" | base64 | tr -d '\n')${p}"
  echo
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
    systemctl restart xray
  else
    echo "cancel"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

update_online() {
  bash -c "$(wget -qO- https://raw.githubusercontent.com/771073216/shell/master/update.sh)" 2>&1 | tee /tmp/update.log
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
  update)
    update_online
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall|info|-m]"
    ;;
esac
