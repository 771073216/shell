#!/usr/bin/env bash
r='\033[0;31m'
g='\033[0;32m'
y='\033[0;33m'
p='\033[0m'
[[ $EUID -ne 0 ]] && echo -e "[${r}Error${p}] 请以root身份执行该脚本！" && exit 1
ssl_dir=/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

set_xray() {
  cat > /usr/local/etc/xray/config.yaml <<- EOF
log:
  loglevel: warning
inbounds:
- port: 443
  protocol: vless
  settings:
    clients:
    - id: ${passwd}
      flow: xtls-rprx-vision
    decryption: none
    fallbacks:
    - dest: '8080'
      xver: 1
  streamSettings:
    network: tcp
    security: tls
    tlsSettings:
      rejectUnknownSni: true
      minVersion: '1.2'
      certificates:
      - certificateFile: "/usr/local/etc/xray/fullchain.cer"
        keyFile: "/usr/local/etc/xray/private.key"
  sniffing:
    enabled: true
    destOverride:
    - http
    - tls
outbounds:
- protocol: freedom
  tag: direct
policy:
  levels:
    '0':
      handshake: 2
      connIdle: 120
      uplinkOnly: 1
      downlinkOnly: 1

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

set_conf() {
  while ! [ -f $ssl_dir/"${domain}"/"${domain}".crt ]; do
    sleep 1
  done
  set_xray
  set_caddy
  copy_ca
}

copy_ca() {
  cp $ssl_dir/"${domain}"/"${domain}".crt /usr/local/share/xray/fullchain.cer
  cp $ssl_dir/"${domain}"/"${domain}".key /usr/local/share/xray/private.key
  cat > /usr/local/share/xray/update.sh <<- EOF
#!/bin/bash
dir="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/"
cer="\${dir}${domain}/${domain}.crt"
key="\${dir}${domain}/${domain}.key"
renew_time=\$(stat -c %Y \$cer)
if [ -e "/usr/local/share/xray/renew" ]; then
  local_time=\$(cat /usr/local/share/xray/renew)
  if [ "\$renew_time" != "\$local_time" ]; then
    echo "updating"
    rm /usr/local/share/xray/fullchain.cer /usr/local/share/xray/private.key
    cp \$cer /usr/local/share/xray/fullchain.cer
    cp \$key /usr/local/share/xray/private.key
    echo "\$renew_time" > /usr/local/share/xray/renew
        echo "done"
  fi
else
  echo "\$renew_time" > /usr/local/share/xray/renew
fi
EOF
  chmod +x /usr/local/share/xray/update.sh
  crontab -l | grep -v "0 0 \* \* 1 bash /usr/local/share/xray/update.sh" | crontab
  (
    crontab -l
    echo "0 0 * * 1 bash /usr/local/share/xray/update.sh"
  ) | crontab
}

install_xray() {
  if dpkg -l | grep xray > /dev/null; then
    update_xray
  fi
  echo -e -n "[${g}Info${p}] 输入域名： "
  read -r domain
  echo -e -n "[${g}Info${p}] 输入密码： "
  read -r passwd
  curl -L https://raw.githubusercontent.com/771073216/deb/main/xray.deb -o xray.deb
  dpkg -i xray.deb && rm xray.deb
  set_conf
  systemctl restart xray caddy
  info_xray
}

update_xray() {
  xray_verison=$(curl -sSL "https://raw.githubusercontent.com/771073216/deb/main/version" | awk '/xray/{print$2}')
  caddy_verison=$(curl -sSL "https://raw.githubusercontent.com/771073216/deb/main/version" | awk '/caddy/{print$2}')
  remote_version=$xray_verison"+"$caddy_verison
  local_version=$(dpkg -s xray | awk '/Version/ {print$2}')
  if ! [ "${remote_version}" == "${local_version}" ]; then
    echo -e "| ${y}xray+caddy${p}  | ${r}${local_version}${p} --> ${g}${remote_version}${p}"
    curl -L https://raw.githubusercontent.com/771073216/deb/main/xray.deb -o xray.deb
    dpkg -i --force-confold xray.deb && rm xray.deb
    echo
    echo -e "[${g}Info${p}] 更新成功！"
    state_xray
  else
    echo -e "| ${y}xray+caddy${p}  | ${g}${local_version}${p}  (latest)"
  fi
  exit 0
}

uninstall_xray() {
  echo -e "[${g}Info${p}] 正在卸载${y}xray${p}..."
  dpkg --purge xray
  echo -e "[${g}Info${p}] 卸载成功！"
}

info_xray() {
  xraystatus=$(pgrep xray)
  caddystatus=$(pgrep caddy)
  echo
  [ -z "$xraystatus" ] && echo -e " xray运行状态：${r}已停止${p}" || echo -e " xray运行状态：${g}正在运行${p}"
  [ -z "$caddystatus" ] && echo -e " caddy运行状态：${r}已停止${p}" || echo -e " caddy运行状态：${g}正在运行${p}"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
  install)
    install_xray
    ;;
  -i)
    info_xray
    ;;
  -u)
    uninstall_xray
    ;;
  *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|-u uninstall|-i info]"
    ;;
esac
