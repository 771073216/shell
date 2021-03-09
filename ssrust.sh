#!/usr/bin/env bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
r='\033[41;37m'
TMP_DIR="$(mktemp -du)"
latest=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | awk -F '"' '/tag_name/ {print $4}')
link=https://github.com/shadowsocks/shadowsocks-rust/releases/latest/download/shadowsocks-$latest.x86_64-unknown-linux-gnu.tar.xz

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

check_ss() {
  if command -v "ssserver" > /dev/null 2>&1; then
    get_update
  fi
}

config_ss() {
  install -d /etc/shadowsocks-rust/
  echo -e -n "[${green}Info${plain}] 输入端口："
  read -r port
  echo -e -n "[${green}Info${plain}] 输入密码："
  read -r passwd
  set_ss
  set_service
  set_bbr
}

set_ss() {
  cat > /etc/shadowsocks-rust/config.json <<- EOF
{
    "server":"::",
    "server_port":$port,
    "password":"$passwd",
    "method":"aes-128-gcm",
    "mode":"tcp_and_udp"
}
EOF
}

set_service() {
  cat > /etc/systemd/system/shadowsocks.service <<- EOF
[Unit]
Description=ss Service
After=network.target
[Service]
Type=simple
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks-rust/config.json
ExecStop=/usr/bin/killall ssserver
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
}

install_file() {
  wget -q --show-progress -cO ss.tar.xz https://api.azzb.workers.dev/"$link"
  tar -oxf ss.tar.xz -C /usr/local/bin/ ssserver
}

install_ss() {
  check_ss
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  echo -e "[${green}Info${plain}] 开始安装${yellow}Shadowsocks-rust${plain}"
  install_file
  rm -rf "$TMP_DIR"
  config_ss
  systemctl enable shadowsocks --now
  echo -e "[${green}Info${plain}] 完成安装！"
  info_ss
}

get_update() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  current=v$(ssserver -V | awk '{print $2}')
  if [ "${latest}" == "${current}" ]; then
    echo -e "[${green}Info${plain}] 已安装最新版本${green}${latest}${plain}"
  else
    echo -ne "[${green}Info${plain}] 正在更新${yellow}Shadowsocks-rust${plain}"
    echo -e " ${red}${current}${plain} --> ${green}${latest}${plain}"
    install_file
    systemctl restart shadowsocks
    echo -e "[${green}Info${plain}] 更新完成！"
  fi
  rm -rf "$TMP_DIR"
  exit 0
}

set_bbr() {
  echo -e "[${green}Info${plain}] 设置bbr..."
  sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
  sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
  (echo "net.core.default_qdisc = fq" && echo "net.ipv4.tcp_congestion_control = bbr") >> '/etc/sysctl.conf'
  sysctl -p > /dev/null 2>&1
}

info_ss(){
  ip=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
  port=$(awk -F ':' '/port/ {print$2}' ../555 | tr -d ',"')
  passwd=$(awk -F ':' '/password/ {print$2}' ../555 | tr -d ',"')
  method=$(awk -F ':' '/method/ {print$2}' ../555 | tr -d ',"')
  echo -e "=========================="
  echo -e "ip: ${r}$ip${plain}"
  echo -e "端口：${r}$port${plain}"
  echo -e "密码：${r}$passwd${plain}"
  echo -e "加密方式：${r}$method${plain}"
  echo -e "=========================="
}

uninstall_ss() {
  echo -e "[${green}Info${plain}] 正在卸载${yellow} Shadowsocks-rust${plain}..."
  systemctl disable shadowsocks --now
  rm /usr/local/bin/ssserver
  rm /etc/systemd/system/shadowsocks.service
  rm -r /etc/shadowsocks-rust/
  echo -e "[${green}Info${plain}] 卸载成功！"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install | uninstall | info)
    ${action}_ss
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall|info]"
    ;;
esac
