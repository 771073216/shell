#!/bin/bash
b() {
  mkdir backup
  cp -r /var/www/ backup/
  cp /etc/ssh/sshd_config backup/
  cp -r .ssh/ backup/
  zip -r backup.zip backup/
}

r() {
  unzip backup.zip
  cp -r backup/www/ /var/
  cp backup/sshd_config /etc/ssh/
  cp -r backup/.ssh/ .
  rm -r backup/
  rm backup.zip
}

action=$1
[ -z "$1" ] && action=b
case "$action" in
  b | r)
    $action
    ;;
esac
