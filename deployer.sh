#!/usr/bin/env bash

main() {
  [ -e out/ ] || mkdir out
  [ "$(ls out/)" != "" ] && rm out/*
  list=$(ldd "$1" | grep "opt/Qt" | awk '{print$3}')
  for i in $list; do
    cp "$i" out/
  done
}

[ -z "$1" ] && echo "$0 binary" && exit 0
main "$1"
