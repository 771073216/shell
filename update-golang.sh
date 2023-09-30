#!/usr/bin/env bash
set -e
latest_ver=$(curl -s https://go.dev/dl/ | grep -v -E 'go[0-9\.]+(beta|rc)' | grep -E -o 'go[0-9\.]+' | grep -E -o '[0-9]\.[0-9]+(\.[0-9]+)?' | sort -V | uniq | tail -n1)
url="https://go.dev/dl/go${latest_ver}.linux-amd64.tar.gz"
go_dir="/usr/local/go"

main() {
  if ! command -v go > /dev/null; then
    install_golang
    exit 0
  fi

  local_ver=$(go version | awk '{print$3}' | cut -c 3-)
  newer_ver=$(echo -e "${latest_ver}\n${local_ver}" | sort -V | tail -n1)

  if [ "$newer_ver" == "$local_ver" ]; then
    echo "go$local_ver is latest version"
  else
    update_golang
  fi
}

update_golang() {
  wget "$url" -O /tmp/golang-update.tar.gz
  [ -e "$go_dir" ] && rm -r "$go_dir"
  tar -xf /tmp/golang-update.tar.gz -C /usr/local
  rm /tmp/golang-update.tar.gz
}

install_golang() {
  update_golang
  echo "export PATH=\$PATH:/usr/local/go/bin" >> "${HOME}"/.profile
}

main
