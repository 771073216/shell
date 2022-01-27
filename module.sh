#!/bin/sh
get_info() {
  i=0
  list=$(ls /data/adb/modules/)
  for module in $list; do
    m=$(awk -F"=" '/name/ {print$2}' /data/adb/modules/"$module"/module.prop)
    i=$((i + 1))
    if [ -f /data/adb/modules/"$module"/disable ]; then
      stat="disabled"
    else
      stat="enabled"
    fi
    echo "[$i] $module ($m) [$stat]"
  done
}

enable_module() {
  echo
  echo "enable which $sum"
  read -r i
  printf "input: "
  [ -z "$i" ] && echo "echo number" && exit 1
  name=$(ls /data/adb/modules/ | awk -v "i=$i" 'NR==i {print$1}')
  if [ -f /data/adb/modules/"$name"/disable ]; then
    rm /data/adb/modules/"$name"/disable
    echo "done"
  else
    echo "$name is enabled"
  fi
}

disable_module() {
  echo
  echo "disable which $sum"
  read -r i
  printf "input: "
  [ -z "$i" ] && echo "echo number" && exit 1
  name=$(ls /data/adb/modules/ | awk -v "i=$i" 'NR==i {print$1}')
  if [ -f /data/adb/modules/"$name"/disable ]; then
    echo "$name is disabled"
  else
    touch /data/adb/modules/"$name"/disable
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
