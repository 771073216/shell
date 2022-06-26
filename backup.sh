#!/bin/bash
b() {
  mkdir backup
  cp /etc/ssh/sshd_config backup/
  cp -r .ssh/ backup/
  cp -r /usr/local/etc/ backup/
  zip -r backup.zip backup/
  rm -r backup/
}

r() {
  unzip backup.zip
  mv backup/sshd_config /etc/ssh/
  cp -r backup/.ssh/ .
  cp -r backup/etc/ /usr/local/
  rm -r backup/
  rm backup.zip
  systemctl restart sshd
}

$1
[ -z "$1" ] && echo "b|r" && exit 0
