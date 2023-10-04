#!/bin/bash
set -e
latest_ver=$(curl -s https://api.github.com/repos/sagernet/sing-box/releases/latest | awk -F'"' '/tag_name/{print$4}' | sort -n | tail -n1 | tr -d v)

main() {
  if ! command -v sing-box > /dev/null; then
    install_sing_box
    exit 0
  fi
  local_ver=$(sing-box version | awk '/version/{print$3}')
  newer_ver=$(echo -e "${latest_ver}\n${local_ver}" | sort -V | tail -n1)
  if [ "$newer_ver" == "$local_ver" ]; then
    echo "sing-box $local_ver is latest version"
  else
    install_sing_box
  fi
}

install_sing_box() {
  wget https://github.com/SagerNet/sing-box/releases/download/v"$latest_ver"/sing-box-"$latest_ver"-linux-amd64.tar.gz -O /tmp/sing-box.tar.gz
  tar -xf /tmp/sing-box.tar.gz -C /tmp/
  install /tmp/sing-box-"$latest_ver"-linux-amd64/sing-box /usr/local/bin/
  rm -r /tmp/sing-box-"$latest_ver"-linux-amd64 /tmp/sing-box.tar.gz
}

if [ "$1" == "-f" ]; then
  install_sing_box
  exit 0
fi

main
