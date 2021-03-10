#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
red='\033[41;37m'
TMP_DIR="$(mktemp -du)"
[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
link=https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip


check_xray() {
  if command -v "xray" > /dev/null 2>&1; then
    update_xray
  fi
}

pre_install(){
  if ! command -v "unzip" > /dev/null 2>&1; then
    apt -y install unzip
  fi
}

set_xray() {
  install -d /usr/local/etc/xray/
  echo -e -n "[${g}Info${p}] 输入端口："
  read -r port
  echo -e -n "[${g}Info${p}] 输入密码："
  read -r passwd
  set_conf
  set_bbr
  set_service
}

set_conf() {
  cat > /usr/local/etc/xray/config.json <<- EOF
{
    "inbounds": [
        {
            "port": $port,
            "protocol": "shadowsocks",
            "settings": {
                "clients": [
                    {
                        "password": "$passwd",
                        "method": "aes-256-gcm"
                    }
                ],
                "network": "tcp,udp"
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

[Install]
WantedBy=multi-user.target
EOF
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
  if [ "${ver}" == "${ver1}" ]; then
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
  pre_install
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
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
  ip=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
  port=$(awk -F ':' '/port/ {print$2}' /usr/local/etc/xray/config.json | tr -d ',"')
  passwd=$(awk -F ':' '/password/ {print$2}' /usr/local/etc/xray/config.json | tr -d ',"')
  method=$(awk -F ':' '/method/ {print$2}' /usr/local/etc/xray/config.json | tr -d ',"')
  echo -e "=========================="
  echo -e "ip: ${red}$ip${p}"
  echo -e "端口：${red}$port${p}"
  echo -e "密码：${red}$passwd${p}"
  echo -e "加密方式：${red}$method${p}"
  echo -e "=========================="
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | info | uninstall)
    ${action}_xray
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|info|-m]"
    ;;
esac
