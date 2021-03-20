#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
TMP_DIR="$(mktemp -du)"
uuid=$(cat /proc/sys/kernel/random/uuid)
date

update_xray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  xray_remote=$(wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  xray_local=v$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}${xray_local}${p} --> ${g}${xray_remote}${p}"
  wget -q --show-progress https://api.azzb.workers.dev/"$link"
  unzip -oq "Xray-linux-64.zip"
  mv xray /usr/local/bin/
  mv geoip.dat geosite.dat /usr/local/share/xray/
  systemctl restart xray
  echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
  rm -rf "$TMP_DIR"
}

update_caddy() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  caddy_remote=$(wget -qO- "https://api.github.com/repos/caddyserver/caddy/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  caddy_ver=$(echo "$caddy_remote" | tr -d v)
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}')
  echo -e "[${g}Info${p}] 正在更新${y}caddy${p}：${r}${caddy_local}${p} --> ${g}${caddy_remote}${p}"
  wget https://github.com/caddyserver/caddy/releases/download/"$caddy_remote"/caddy_"$caddy_ver"_linux_amd64.deb
  dpkg -i caddy_"$caddy_ver"_linux_amd64.deb
  echo -e "[${g}Info${p}] ${y}caddy${p}更新成功！"
  rm -rf "$TMP_DIR"
}

set_xray() {
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
