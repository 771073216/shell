#!/bin/bash
b() {
  mkdir backup
  cp -r /var/www/ backup/
  cp /etc/ssh/sshd_config backup/
  cp -r .ssh/ backup/
  cp -r /etc/caddy/ backup/
  cp -r /usr/local/etc/xray/ backup/
  zip -r backup.zip backup/
  rm -r backup/
}

r() {
  unzip backup.zip
  cp -r backup/www/ /var/
  mv backup/sshd_config /etc/ssh/
  cp -r backup/.ssh/ .
  cp -r backup/caddy/ /etc/
  cp -r backup/xray/ /usr/local/etc/
  mkdir /var/log/xray
  chown -R nobody:nogroup /var/log/xray
  rm -r backup/
  rm backup.zip
  systemctl restart xray caddy sshd
}

action=$1
[ -z "$1" ] && echo "b|r" && exit 0
case "$action" in
  b | r)
    $action
    ;;
esac
