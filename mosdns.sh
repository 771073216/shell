#!/bin/sh
echo "[1] restart mosdns"
echo "[2] update mosdns"
echo "[3] update geofile"
echo "[4] stop mosdns"
echo "[5] start mosdns"
echo "[6] install mosdns"
echo "[7] install redis-server"
echo "[8] setup redis-server"
echo "[9] setup mosdns"
printf "[input]: "
read -r select

arch=$(awk -F'"' '/OPENWRT_ARCH/{print$2}' /etc/os-release)
board=$(awk -F'"' '/OPENWRT_BOARD/{print$2}' /etc/os-release)
if [ "$arch" = "x86_64" ]; then
  mosdns_arch="amd64"
else
  mosdns_arch="arm64"
fi

clean_log() {
  log_file=$(grep -A 3 'log:' /etc/mosdns/config.yaml | awk -F'"' '/file:/{print$2}')
  [ -e "$log_file" ] && rm "$log_file"
}

if [ "$select" = 1 ]; then
  clean_log
  /etc/init.d/mosdns restart
fi

if [ "$select" = 2 ]; then
  local_ver=$(mosdns version | awk -F"-" '{print$1}')
  remote_ver=$(curl -sSL https://api.github.com/repos/IrineSistiana/mosdns/releases/latest | awk -F'"' '/tag_name/{print$4}')
  if [ "$local_ver" = "$remote_ver" ]; then
    return
  fi
  mkdir /tmp/mosdns-update
  curl -L https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-${mosdns_arch}.zip -o /tmp/mosdns-update/mosdns.zip
  unzip /tmp/mosdns-update/mosdns.zip mosdns -d /tmp/mosdns-update
  rm /usr/bin/mosdns
  mv /tmp/mosdns-update/mosdns /usr/bin/mosdns
  rm -r /tmp/mosdns-update
  echo "$local_ver -> $remote_ver"
  clean_log
  /etc/init.d/mosdns restart
fi

if [ "$select" = 3 ]; then
  version=$(curl -sSL "https://api.github.com/repos/771073216/geofile/releases/latest" | awk -F '"' '/tag_name/ {print $4}')
  if [ -e /usr/share/v2ray/version ]; then
    local_ver=$(cat /usr/share/v2ray/version)
  else
    local_ver=0
  fi
  if [ "$version" != "$local_ver" ]; then
    curl -L https://raw.githubusercontent.com/771073216/geofile/release/geoip.dat -o /usr/share/v2ray/geoip.dat
    curl -L https://raw.githubusercontent.com/771073216/geofile/release/geosite.dat -o /usr/share/v2ray/geosite.dat
    echo "$version" > /usr/share/v2ray/version
  fi
fi

if [ "$select" = 4 ]; then
  /etc/init.d/mosdns stop
  clean_log
  uci delete dhcp.@dnsmasq[0].server
  uci set dhcp.@dnsmasq[0].noresolv=0
  uci delete dhcp.@dnsmasq[0].cachesize
  uci set dhcp.@dnsmasq[0].resolvfile="/tmp/resolv.conf.d/resolv.conf.auto"
  uci commit dhcp
  /etc/init.d/dnsmasq restart &
fi

if [ "$select" = 5 ]; then
  /etc/init.d/mosdns start
  clean_log
  port=$(grep 127.0.0.1 /etc/mosdns/config.yaml | awk -F':' 'NR==1 && /addr/{print$3}')
  server=$(uci get dhcp.@dnsmasq[0].server)
  if [ "$server" != "" ]; then
    uci delete dhcp.@dnsmasq[0].server
  fi
  uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$port"
  uci set dhcp.@dnsmasq[0].noresolv=1
  uci set dhcp.@dnsmasq[0].cachesize=0
  uci commit dhcp
  /etc/init.d/dnsmasq restart &
fi

if [ "$select" = 6 ]; then
  mkdir /tmp/mosdns-install /etc/mosdns
  curl -L https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-${mosdns_arch}.zip -o /tmp/mosdns-install/mosdns.zip
  curl -L https://raw.githubusercontent.com/IrineSistiana/mosdns/main/scripts/openwrt/mosdns-init-openwrt -o /etc/init.d/mosdns
  unzip /tmp/mosdns-install/mosdns.zip mosdns -d /usr/bin/
  chmod +x /etc/init.d/mosdns
  /etc/init.d/mosdns enable
  rm -r /tmp/mosdns-install
fi

if [ "$select" = 7 ]; then
  mkdir /usr/share/redis
  redis=$(curl -s https://mirrors.cloud.tencent.com/lede/snapshots/packages/"$arch"/packages/ | awk -F'"' '/redis-server/ {print$2}')
  dep_atomtic=$(curl -s https://mirrors.cloud.tencent.com/lede/snapshots/targets/"$board"/packages/ | awk -F'"' '/libatomic1/ {print$2}')
  dep_pthread=$(curl -s https://mirrors.cloud.tencent.com/lede/snapshots/targets/"$board"/packages/ | awk -F'"' '/libpthread/ {print$2}')
  curl -L https://mirrors.cloud.tencent.com/lede/snapshots/packages/"$arch"/packages/"$redis" -o "$redis"
  curl -L https://mirrors.cloud.tencent.com/lede/snapshots/targets/"$board"/packages/"$dep_atomtic" -o "$dep_atomtic"
  curl -L https://mirrors.cloud.tencent.com/lede/snapshots/targets/"$board"/packages/"$dep_pthread" -o "$dep_pthread"
  opkg install "$dep_atomtic" "$dep_pthread" "$redis"
  rm "$dep_atomtic" "$dep_pthread" "$redis"
fi

if [ "$select" = 8 ]; then
  mkdir /usr/share/redis
  conf_path="/etc/redis.conf"
  sed -i '/^maxmemory /d' $conf_path
  sed -i '/^maxmemory-policy /d' $conf_path
  sed -i '/^dbfilename /d' $conf_path
  sed -i '/^dir /d' $conf_path
  {
    echo "maxmemory 8mb"
    echo "maxmemory-policy allkeys-lru"
    echo "dbfilename dns.rdb"
    echo "dir /usr/share/redis"
  } >> $conf_path
fi

if [ "$select" = 9 ]; then
  cat >> /etc/mosdns/config.yaml <<- EOF
log:
  level: info
  file: "/tmp/mosdns.log"

plugins:
  - tag: cache
    type: cache
    args:
      size: 4096
      redis: 'redis://localhost:6379/0'
      lazy_cache_ttl: 86400

  - tag: forward_local
    type: fast_forward
    args:
      upstream:
        - addr: 61.134.1.5
        - addr: 218.30.19.50

  - tag: forward_remote
    type: fast_forward
    args:
      upstream:
        - addr: tls://1.1.1.1
          enable_pipeline: true

  - tag: local_sequence
    type: sequence
    args:
      exec:
        - cache
        - forward_local

  - tag: remote_sequence
    type: sequence
    args:
      exec:
        - cache
        - forward_remote

servers:
  - exec: local_sequence
    listeners:
      - protocol: udp
        addr: 127.0.0.1:5335
      - protocol: tcp
        addr: 127.0.0.1:5335

  - exec: remote_sequence
    listeners:
      - protocol: udp
        addr: 127.0.0.1:6053
      - protocol: tcp
        addr: 127.0.0.1:6053
EOF
fi
