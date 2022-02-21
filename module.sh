#!/bin/sh
get_info() {
  i=0
  list=$(find /data/adb/modules/ -mindepth 1 -maxdepth 1)
  for module in $list; do
    m=$(awk -F"=" '/name/ {print$2}' "$module"/module.prop)
    module_name=$(basename "$module")
    i=$((i + 1))
    if [ -f "$module"/disable ]; then
      stat="disabled"
    else
      stat="enabled"
    fi
    echo "[$i] $module_name ($m) [$stat]"
  done
}

enable_module() {
  echo
  echo "enable which $sum"
  printf "input: "
  read -r i
  [ -z "$i" ] && echo "echo number" && exit 1
  module=$(echo "$list" | awk -v "i=$i" 'NR==i {print$1}')
  module_name=$(basename "$module")
  if [ -f "$module"/disable ]; then
    rm "$module"/disable
    echo "done"
  else
    echo "$module_name is enabled"
  fi
}

disable_module() {
  echo
  echo "disable which $sum"
  printf "input: "
  read -r i
  [ -z "$i" ] && echo "echo number" && exit 1
  module=$(echo "$list" | awk -v "i=$i" 'NR==i {print$1}')
  module_name=$(basename "$module")
  if [ -f "$module"/disable ]; then
    echo "$module_name is disabled"
  else
    touch "$module"/disable
    echo "done"
  fi
}

main() {
  clear
  get_info
  if [ "$i" = 1 ]; then
    sum=""
  else
    sum="[1-$i]"
  fi
  echo
  echo "enable or disable"
  echo "[1] enable"
  echo "[2] disable"
  printf "input: "
  read -r choice
  if [ "$choice" = 1 ]; then
    enable_module
  elif [ "$choice" = 2 ]; then
    disable_module
  else
    echo "input correct number"
  fi
}

main
