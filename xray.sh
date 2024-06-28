#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1

set_conf() {
  private_key=$(xray x25519 | awk '{print$3}' | head -n 1)
  cat > /usr/local/etc/xray/config.json <<- EOF
{
    "log": {
        "loglevel": "info",
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log"
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:cn",
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "password",
                        "flow": ""
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.example.com:443",
                    "xver": 0,
                    "serverNames": [
                        "www.example.com"
                    ],
                    "privateKey": "${private_key}",
                    "shortIds": [
                        ""
                    ]
                },
                "grpcSettings": {
                    "serviceName": "grpc"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
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
DynamicUser=1
LogsDirectory=xray
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -c /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
}

install() {
  if command -v xray; then
    update
    exit 0
  fi
  mkdir -p /usr/local/etc/xray/ /usr/local/share/xray/
  set_service
  set_conf
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -O /tmp/xray.zip
  unzip /tmp/xray.zip xray -d /usr/local/bin
  chmod +x /usr/local/bin/xray
}

update() {
  latest_version=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/releases/latest | awk -F '"' '/tag_name/ {print $4}')
  local_version=$(/usr/local/bin/xray version | awk 'NR==1 {print "v"$2}')
  [ "$latest_version" == "$local_version" ] && echo "no update" && exit 0
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -O /tmp/xray.zip
  unzip /tmp/xray.zip xray -d /usr/local/bin
  chmod +x /usr/local/bin/xray
  systemctl restart xray
}

uninstall() {
  echo -e "[${g}Info${p}] 正在卸载${y}xray${p}..."
  systemctl disable xray --now
  rm -f /usr/local/bin/xray
  rm -rf /usr/local/etc/xray/
  rm -f /etc/systemd/system/xray.service
  echo -e "[${g}Info${p}] 卸载成功！"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | uninstall)
    "${action}"
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall]"
    ;;
esac
