#!/usr/bin/env bash
[[ $EUID -ne 0 ]] && echo -e "请以root身份执行该脚本！" && exit 1

main() {
  if command -v vnstat; then
    update
    return
  fi
  curl -L https://raw.githubusercontent.com/771073216/deb/main/vnstat.deb -o vnstat.deb
  dpkg -i vnstat.deb
  rm vnstat.deb
}

update() {
  local_ver=$(vnstat -v | awk '{print$2}')
  remote_ver=$(curl -sSL https://raw.githubusercontent.com/771073216/deb/main/version | awk '/vnstat/{print$2}')
  if [ "${local_ver}" == "${remote_ver}" ]; then
    return
  fi
  curl -L https://raw.githubusercontent.com/771073216/deb/main/vnstat.deb -o vnstat.deb
  dpkg -i vnstat.deb
  rm vnstat.deb
}

main
