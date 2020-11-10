#!/bin/bash
b() {
  mkdir backup
  cp -r /var/www/ backup/
  cp /etc/ssh/ssh_config backup/
  zip -r backup.zip backup/
}

r() {
  unzip backup.zip
  cp -r backup/www/ /var/
  cp backup/ssh_config /etc/ssh/
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
