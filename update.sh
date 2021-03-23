#!/usr/bin/env bash
TMP_DIR="$(mktemp -du)"
h2conf=/usr/local/etc/xray/h2.json
wsconf=/usr/local/etc/xray/ws.json
grpcconf=/usr/local/etc/xray/grpc.json
echo "time:$(date)"

update_xray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  xray_remote=$(wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  xray_local=v$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  echo "正在更新xray：${xray_local} --> ${xray_remote}"
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  unzip -oq "Xray-linux-64.zip"
  mv xray /usr/local/bin/
  mv geoip.dat geosite.dat /usr/local/share/xray/
  systemctl restart xray
  echo "xray更新成功！"
  rm -rf "$TMP_DIR"
}

update_caddy() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  caddy_remote=$(wget -qO- "https://api.github.com/repos/caddyserver/caddy/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  caddy_ver=$(echo "$caddy_remote" | tr -d v)
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}')
  echo "正在更新caddy：${caddy_local} --> ${caddy_remote}"
  wget https://github.com/caddyserver/caddy/releases/download/"$caddy_remote"/caddy_"$caddy_ver"_linux_amd64.deb
  dpkg -i caddy_"$caddy_ver"_linux_amd64.deb
  echo "caddy更新成功！"
  rm -rf "$TMP_DIR"
}

h2_conf() {
  h2uuid=$(awk -F'"' '/"id"/ {print$4}' $h2conf)
  h2path=$(awk -F'"' '/"path"/ {print$4}' $h2conf | tr -d /)
  domain=$(grep -A 1 host $h2conf | grep -v host | awk -F'"' '{print$2}')
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
          "path": "/${h2path}",
          "host": [
            "${domain}"
          ]
        }
      }
    }
  ]
}
EOF
}

ws_conf(){
  wsuuid=$(awk -F'"' '/"id"/ {print$4}' $wsconf)
  wspath=$(awk -F'"' '/"path"/ {print$4}' $wsconf | tr -d /)
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
          "path": "/${wspath}"
        }
      }
    }
  ]
}
EOF
}

grpc_conf(){
  grpcuuid=$(awk -F'"' '/"id"/ {print$4}' $grpcconf)
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
}

set_caddy() {
  wspath=$(awk -F'"' '/"path"/ {print$4}' $wsconf | tr -d /)
  h2path=$(awk -F'"' '/"path"/ {print$4}' $h2conf | tr -d /)
  domain=$(grep -A 1 host $h2conf | grep -v host | awk -F'"' '{print$2}')
  cat > /etc/caddy/Caddyfile <<- EOF
${domain} {
    @ws {
        path /${wspath}
        header Connection *Upgrade*
        header Upgrade websocket
    }
    @grpc protocol grpc
    reverse_proxy @ws http://127.0.0.1:2001
    reverse_proxy @grpc h2c://127.0.0.1:2002
    reverse_proxy /${h2path} h2c://127.0.0.1:2003
    root * /var/www
    file_server
}
EOF
  systemctl restart caddy
}

restart_xray(){
  systemctl restart xray
}

restart_caddy(){
  systemctl restart caddy
}
