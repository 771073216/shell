#!/usr/bin/env bash
remote_ver=$(curl -sSL https://api.github.com/repos/vergoh/vnstat/releases/latest | awk -F'"' '/tag_name/{print$4}' | tr -d v)
main() {
  if command -v vnstat; then
    update
    return
  fi
  apt install -y build-essential libsqlite3-dev git
  curl -L https://codeload.github.com/vergoh/vnstat/zip/refs/tags/v"${remote_ver}" && cd vnstat || exit 1
  ./configure --prefix=/usr --sysconfdir=/etc && make && make install
  cp examples/systemd/vnstat.service /etc/systemd/system/
  systemctl enable vnstat.service --now
  cd .. && rm -r vnstat
}

update() {
  local_ver=$(vnstat -v | awk '{print$2}')
  if [ "${local_ver}" == "${remote_ver}" ]; then
    return
  fi
  [ -e vnstat ] && rm -r vnstat
  curl -L https://codeload.github.com/vergoh/vnstat/zip/refs/tags/v"${remote_ver}" -o vnstat.zip
  unzip vnstat.zip
  cd vnstat-"$remote_ver" || exit 1
  ./configure --prefix=/usr --sysconfdir=/etc && make && make install
  cp examples/systemd/vnstat.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl restart vnstat
  cd .. && rm -r vnstat-"$remote_ver"
}

main
