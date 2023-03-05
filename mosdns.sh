#!/bin/sh
echo "[1] restart mosdns"
echo "[2] update mosdns"
echo "[3] stop mosdns"
echo "[4] start mosdns"
echo "[5] install mosdns"
echo "[6] setup mosdns"
echo "[7] force install mosdns"
printf "[input]: "
read -r select

arch=$(awk -F'"' '/OPENWRT_ARCH/{print$2}' /etc/os-release)
if [ "$arch" = "x86_64" ]; then
  mosdns_arch="amd64"
else
  mosdns_arch="arm64"
fi

clean_log() {
  log_file=$(grep -A 3 'log:' /etc/mosdns/config.yaml | awk -F'"' '/file:/{print$2}')
  [ -e "$log_file" ] && rm "$log_file"
}

dl_mosdns() {
  mkdir /tmp/mosdns-update
  curl -L https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-${mosdns_arch}.zip -o /tmp/mosdns-update/mosdns.zip
  unzip /tmp/mosdns-update/mosdns.zip mosdns -d /tmp/mosdns-update
  rm /usr/bin/mosdns
  mv /tmp/mosdns-update/mosdns /usr/bin/mosdns
  rm -r /tmp/mosdns-update
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
  dl_mosdns
  echo "$local_ver -> $remote_ver"
  clean_log
  /etc/init.d/mosdns restart
fi

if [ "$select" = 3 ]; then
  /etc/init.d/mosdns stop
  clean_log
  uci delete dhcp.@dnsmasq[0].server
  uci set dhcp.@dnsmasq[0].noresolv=0
  uci delete dhcp.@dnsmasq[0].cachesize
  uci set dhcp.@dnsmasq[0].resolvfile="/tmp/resolv.conf.d/resolv.conf.auto"
  uci commit dhcp
  /etc/init.d/dnsmasq restart &
fi

if [ "$select" = 4 ]; then
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

if [ "$select" = 5 ]; then
  mkdir /tmp/mosdns-install /etc/mosdns /usr/share/mosdns
  curl -L https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-${mosdns_arch}.zip -o /tmp/mosdns-install/mosdns.zip
  curl -L https://raw.githubusercontent.com/IrineSistiana/mosdns/main/scripts/openwrt/mosdns-init-openwrt -o /etc/init.d/mosdns
  unzip /tmp/mosdns-install/mosdns.zip mosdns -d /usr/bin/
  chmod +x /etc/init.d/mosdns
  /etc/init.d/mosdns enable
  rm -r /tmp/mosdns-install
fi

if [ "$select" = 6 ]; then
  cat > /etc/mosdns/config.yaml <<- EOF
log:
  level: info
  file: "/tmp/mosdns.log"

plugins:
  - tag: cache
    type: cache
    args:
      size: 4096
      lazy_cache_ttl: 86400
      dump_file: /usr/share/mosdns/cache.dump


  - tag: forward_cn
    type: forward
    args:
      upstreams:
        - addr: tls://dot.pub
          enable_pipeline: true
          dial_addr: 1.12.12.12
     
  - tag: forward_hk
    type: forward
    args:
      upstreams:
        - addr: tls://1.1.1.1
          enable_pipeline: true

          
  - tag: sequence_local
    type: sequence
    args:
      - exec: \$cache
      - matches:
          - has_resp
        exec: accept
      - exec: \$forward_cn
      
  - tag: sequence_remote
    type: sequence
    args:
      - exec: \$cache
      - matches:
          - has_resp
        exec: accept
      - exec: \$forward_hk

  - tag: server_remote
    type: udp_server
    args:
      entry: sequence_local
      listen: 127.0.0.1:5335
      
  - tag: server_local
    type: udp_server
    args:
      entry: sequence_remote
      listen: 127.0.0.1:6053
api:
    http: "192.168.1.1:8080"
EOF
fi

if [ "$select" = 7 ]; then
  dl_mosdns
  clean_log
  /etc/init.d/mosdns restart
fi
