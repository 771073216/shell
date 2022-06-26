#!/bin/sh
echo "[1] update mosdns"
echo "[2] install mosdns"
echo "[3] uninstall mosdns"
printf "[input]: "
read -r select

if [ "$select" = 1 ]; then
  local_ver=$(mosdns version | awk -F"-" '{print$1}')
  remote_ver=$(curl -sSL https://api.github.com/repos/IrineSistiana/mosdns/releases/latest | awk -F'"' '/tag_name/{print$4}')
  if [ "$local_ver" = "$remote_ver" ]; then
    return
  fi
  curl -L https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-amd64.zip -o mosdns-linux-amd64.zip
  unzip -o mosdns-linux-amd64.zip mosdns -d /usr/local/bin/
  rm mosdns-linux-amd64.zip
  echo "$local_ver -> $remote_ver"
  systemctl restart mosdns.service
fi

if [ "$select" = 2 ]; then
  mkdir -p /usr/local/etc/mosdns/
  cat > /etc/systemd/system/mosdns.service <<- EOF
[Unit]
Description=A DNS forwarder
ConditionFileIsExecutable=/usr/local/bin/mosdns

[Service]
StartLimitInterval=5
StartLimitBurst=10
ExecStartPre=/usr/bin/bash -c 'touch /tmp/mosdns.log && rm /tmp/mosdns.log'
ExecStart=/usr/local/bin/mosdns "start" "-c" "/usr/local/etc/mosdns/config.yaml"
Restart=always
RestartSec=120
EnvironmentFile=-/etc/sysconfig/mosdns

[Install]
WantedBy=multi-user.target
EOF

  [ -e /usr/local/etc/mosdns/config.yaml ] || cat > /usr/local/etc/mosdns/config.yaml <<- EOF
log:
  level: info
  file: "/tmp/mosdns.log"

plugins:
  - tag: forward_cloudflare
    type: fast_forward
    args:
      upstream:
        - addr: tls://1.1.1.1
          enable_pipeline: true
        - addr: tls://1.0.0.1
          enable_pipeline: true

servers:
  - exec: forward_cloudflare
    listeners:
      - protocol: udp
        addr: 127.0.0.1:53
      - protocol: tcp
        addr: 127.0.0.1:53
EOF
  curl -L https://github.com/IrineSistiana/mosdns/releases/latest/download/mosdns-linux-amd64.zip -o mosdns-linux-amd64.zip
  unzip mosdns-linux-amd64.zip mosdns -d /usr/local/bin/
  rm mosdns-linux-amd64.zip
  systemctl enable mosdns.service --now
fi

if [ "$select" = 3 ]; then
  rm /etc/systemd/system/mosdns.service /usr/local/bin/mosdns
  systemctl disable mosdns.service --now
fi
