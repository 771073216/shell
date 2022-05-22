#!/bin/sh
echo "[1] restart mosdns"
echo "[2] cat mosdns log"
echo "[3] update mosdns"
echo "[4] update geofile"
echo "[stop] stop mosdns"
echo "[start] start mosdns"
echo "[install] install mosdns"
echo "[redis] install redis-server"
printf "[input]: "
read -r select

arch=$(awk -F'"' '/OPENWRT_ARCH/{print$2}' /etc/os-release)
if [ "$arch" = "x86_64" ]; then
  mosdns_arch="amd64"
else
  mosdns_arch="arm64"
fi

if [ "$select" = 1 ]; then
  log_file=$(awk -F"'" '/log/&&/file/{print$2}' /etc/mosdns/config.yaml)
  echo "" > "$log_file"
  /etc/init.d/mosdns restart
fi

if [ "$select" = 2 ]; then
  log_file=$(awk -F"'" '/log/&&/file/{print$2}' /etc/mosdns/config.yaml)
  cat "$log_file"
fi

if [ "$select" = 3 ]; then
  local_ver=$(mosdns -v | awk -F"-" '{print$1}')
  remote_ver=$(curl -sSL https://api.github.com/repos/IrineSistiana/mosdns/releases/latest | awk -F'"' '/tag_name/{print$4}')
  if [ "$local_ver" = "$remote_ver" ]; then
    return
  fi
  mkdir /tmp/mosdns-update
  curl -sSL https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-${mosdns_arch}.zip -o /tmp/mosdns-update/mosdns.zip
  unzip /tmp/mosdns-update/mosdns.zip mosdns -d /tmp/mosdns-update
  rm /usr/bin/mosdns
  mv /tmp/mosdns-update/mosdns /usr/bin/mosdns
  rm -r /tmp/mosdns-update
  echo "$local_ver -> $remote_ver"
  log_file=$(awk -F"'" '/log/&&/file/{print$2}' /etc/mosdns/config.yaml)
  echo "" > "$log_file"
  /etc/init.d/mosdns restart
fi

if [ "$select" = 4 ]; then
  version=$(curl -sSL "https://api.github.com/repos/771073216/geofile/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  if [ -e /usr/share/v2ray/version ]; then
    local_ver=$(cat /usr/share/v2ray/version)
  else
    local_ver=0
  fi
  if [ "$version" != "$local_ver" ]; then
    wget -q https://github.com/771073216/geofile/releases/latest/download/geoip.dat -O /usr/share/v2ray/geoip.dat
    wget -q https://github.com/771073216/geofile/releases/latest/download/geosite.dat -O /usr/share/v2ray/geosite.dat
    echo "$version" > /usr/share/v2ray/version
  fi
fi

if [ "$select" = "stop" ]; then
  /etc/init.d/mosdns stop
  uci delete dhcp.@dnsmasq[0].server
  uci set dhcp.@dnsmasq[0].noresolv=0
  uci delete dhcp.@dnsmasq[0].cachesize
  uci set dhcp.@dnsmasq[0].resolvfile="/tmp/resolv.conf.d/resolv.conf.auto"
  uci commit dhcp
  /etc/init.d/dnsmasq restart &
fi

if [ "$select" = "start" ]; then
  /etc/init.d/mosdns start
  port=$(grep 127.0.0.1 /etc/mosdns/config.yaml | awk -F':' 'NR==1 && /addr/{print$3}')
  uci delete dhcp.@dnsmasq[0].server
  uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$port"
  uci set dhcp.@dnsmasq[0].noresolv=1
  uci set dhcp.@dnsmasq[0].cachesize=0
  uci commit dhcp
  /etc/init.d/dnsmasq restart &
fi

if [ "$select" = "install" ]; then
  mkdir /tmp/mosdns-install /etc/mosdns
  wget https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-${mosdns_arch}.zip -O /tmp/mosdns-install/mosdns.zip
  unzip /tmp/mosdns-install/mosdns.zip mosdns -d /usr/bin/
  wget https://raw.githubusercontent.com/IrineSistiana/mosdns/main/scripts/openwrt/mosdns-init-openwrt -O /etc/init.d/mosdns
  chmod +x /etc/init.d/mosdns
  /etc/init.d/mosdns enable
  rm -r /tmp/mosdns-install
fi

if [ "$select" = "redis" ]; then
  mkdir /usr/share/redis
  file=$(curl -s https://mirrors.cloud.tencent.com/lede/snapshots/packages/"$arch"/packages/ | awk -F'"' '/redis-server/ {print$2}')
  wget https://mirrors.cloud.tencent.com/lede/snapshots/packages/"$arch"/packages/"$file" -O /root/"$file"
fi
