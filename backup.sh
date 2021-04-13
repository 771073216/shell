#!/bin/bash
b() {
  mkdir backup
  cp -r /var/www/ backup/
  cp /etc/ssh/sshd_config backup/
  cp -r .ssh/ backup/
  cp -r /etc/smartdns/ backup/
  cp -r /etc/caddy/ backup/
  cp -r /usr/local/etc/xray/ backup/
  cp AdGuardHome/AdGuardHome.yaml backup/
  zip -r backup.zip backup/
}

r() {
  https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz
  tar xvf AdGuardHome_linux_amd64.tar.gz
  rm AdGuardHome_linux_amd64.tar.gz
  apt install smartdns -y
  unzip backup.zip
  cp -r backup/www/ /var/
  mv backup/sshd_config /etc/ssh/
  mv backup/AdGuardHome.yaml AdGuardHome/
  cp -r backup/.ssh/ .
  cp -r backup/smartdns/ /etc/
  cp -r backup/caddy/ /etc/
  cp -r backup/xray/ /usr/local/etc/
  rm -r backup/
  rm backup.zip
}

action=$1
[ -z "$1" ] && echo "b|r" && exit 0
case "$action" in
  b | r)
    $action
    ;;
esac
