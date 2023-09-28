#!/bin/bash
latest_ver=$(curl -s https://api.github.com/repos/sagernet/sing-box/tags | awk -F'"' '/name/{print$4}' | sort -n | tail -n1)

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
  ver=$(echo "$latest_ver" | cut -c 2-)
  wget https://github.com/SagerNet/sing-box/releases/download/"$latest_ver"/sing-box_"$ver"_linux_amd64.tar.gz -O /tmp/sing-box.tar.gz
  tar -xf /tmp/sing-box.tar.gz -C /tmp/
  install /tmp/sing-box-"$ver"-linux-amd64/sing-box /usr/local/bin/
  rm -r /tmp/sing-box-"$ver"-linux-amd64 /tmp/sing-box.tar.gz
}

if [ "$1" == "-f" ]; then
  install_sing_box
  exit 0 
fi
main
