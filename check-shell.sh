#!/usr/bin/env bash
if ! command -v shfmt > /dev/null; then
  sudo apt install shfmt
fi
if ! command -v shellcheck > /dev/null; then
  sudo apt install shellcheck
fi
[ -z "$1" ] && exit 0
shfmt -w -i 2 -ci -sr "$@"

shellcheck "$@"
