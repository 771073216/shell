#!/bin/bash
latest_ver=$(curl -s https://api.github.com/repos/sagernet/sing-box/tags | awk -F'"' '/name/{print$4}' | sort -n | tail -n1)
tags="with_reality_server"

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
  go install -v -tags "${tags}" -ldflags "-s -w -buildid= -X github.com/sagernet/sing-box/constant.Version=${latest_ver}" github.com/sagernet/sing-box/cmd/sing-box@"${latest_ver}"
  install "${HOME}"/go/bin/sing-box /usr/local/bin/
}

main
