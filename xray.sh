#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
TMP_DIR="$(mktemp -du)"
uuid=$(cat /proc/sys/kernel/random/uuid)
[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
ssl_dir=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

set_xray() {
  install -d /usr/local/etc/xray/
  set_conf
  set_bbr
  while ! [ -f $ssl_dir/"${domain}"/"${domain}".crt ]; do
    sleep 1
  done
  ln -s $ssl_dir/"${domain}"/"${domain}".crt /usr/local/etc/xray/xray.crt
  ln -s $ssl_dir/"${domain}"/"${domain}".key /usr/local/etc/xray/xray.key
  set_service
}

set_conf() {
  cat > /usr/local/etc/xray/config.yaml <<- EOF
inbounds:
- port: 443
  protocol: vless
  settings:
    clients:
    - id: "${uuid}"
      flow: xtls-rprx-direct
    decryption: none
    fallbacks:
    - dest: 8080
  streamSettings:
    network: tcp
    security: xtls
    xtlsSettings:
      alpn:
      - http/1.1
      certificates:
      - certificateFile: "/usr/local/etc/xray/xray.crt"
        keyFile: "/usr/local/etc/xray/xray.key"
outbounds:
- protocol: freedom
EOF
}

set_caddy() {
  cat > /etc/caddy/Caddyfile <<- EOF
http://${domain} {
    redir https://{host}{uri}
}

https://${domain}:8443 {

}

${domain}:8080 {
    root * /var/www
    file_server
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
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.yaml

[Install]
WantedBy=multi-user.target
EOF
}

install_xray() {
  [ -f /usr/local/bin/xray ] && update_xray
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  mkdir -p /usr/local/etc/xray/ /etc/caddy/ /var/www/
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/caddy.deb
  dpkg -i caddy.deb
  set_caddy
  systemctl restart caddy
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip
  unzip -oq "html.zip" -d /var/www/
  wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/xray-linux.zip
  unzip -oq "xray-linux.zip" xray -d /usr/local/bin/
  rm -rf "$TMP_DIR"
  set_xray
  systemctl enable xray --now
  info_xray
}

update_xray() {
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  wget -q "https://cdn.jsdelivr.net/gh/771073216/dist@main/version"
  xray_remote=$(awk '/xray/ {print$2}' version)
  caddy_remote=$(awk '/caddy/ {print$2}' version)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  caddy_local=$(/usr/bin/caddy version | awk '{print$1}' | tr -d v)
  remote_num=$(echo "$xray_remote" | tr -d .)
  local_num=$(echo "$xray_local" | tr -d .)
  if [ "${local_num}" -lt "${remote_num}" ]; then
    echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}v${xray_local}${p} --> ${g}v${xray_remote}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/xray-linux.zip
    unzip -oq "xray-linux.zip" xray -d /usr/local/bin/
    systemctl restart xray
    echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
  fi
  if ! [ "${caddy_local}" == "${caddy_remote}" ]; then
    echo -e "[${g}Info${p}] 正在更新${y}caddy${p}：${r}v${caddy_local}${p} --> ${g}v${caddy_remote}${p}"
    wget -q --show-progress https://cdn.jsdelivr.net/gh/771073216/dist@main/caddy.deb
    dpkg -i caddy.deb
    echo -e "[${g}Info${p}] ${y}caddy${p}更新成功！"
  fi
  if [ "${local_num}" -gt "${remote_num}" ]; then
    echo -e "[${g}Info${p}] ${y}xray${p}已安装pre版本${g}${xray_local}${p}。"
  else
    echo -e "[${g}Info${p}] ${y}xray${p}已安装最新版本${g}${xray_remote}${p}。"
  fi
  echo -e "[${g}Info${p}] ${y}caddy${p}已安装最新版本${g}${caddy_remote}${p}。"
  rm -rf "$TMP_DIR"
  exit 0
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
  status=$(pgrep -a xray | grep -c xray)
  [ ! -f /usr/local/etc/xray/config.yaml ] && echo -e "[${r}Error${p}] 未找到xray配置文件！" && exit 1
  [ "$status" -eq 0 ] && xraystatus="${r}已停止${p}" || xraystatus="${g}正在运行${p}"
  echo -e " id： ${g}$(grep < '/usr/local/etc/xray/config.json' id | cut -d'"' -f4)${p}"
  echo -e " xray运行状态：${xraystatus}"
}

manual() {
  ver=$(wget -qO- https://api.github.com/repos/XTLS/Xray-core/tags | awk -F '"' '/name/ {print $4}' | head -n 1)
  xray_local=$(/usr/local/bin/xray -version | awk 'NR==1 {print $2}')
  mkdir "$TMP_DIR"
  cd "$TMP_DIR" || exit 1
  echo -e "[${g}Info${p}] 正在更新${y}xray${p}：${r}v${xray_local}${p} --> ${g}${ver}${p}"
  wget -q --show-progress https://github.com/XTLS/Xray-core/releases/download/"$ver"/Xray-linux-64.zip
  unzip -oq "Xray-linux-64.zip" xray -d /usr/local/bin/
  rm -rf "$TMP_DIR"
  systemctl restart xray
  echo -e "[${g}Info${p}] ${y}xray${p}更新成功！"
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
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|info|-m]"
    ;;
esac
