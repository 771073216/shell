#!/bin/bash
num=0
list=$(find /data/data/ -name "app_tbs*")
for file in $list; do
  if find "${file}"/* > /dev/null 2>&1; then
    rm -r "${file:?}"/*
    chattr -i "$file"
    chmod 000 "$file"
    num=$((num + 1))
  fi
done
if [ $num -ne 0 ]; then
  echo "delete $num folder"
else
  echo "not found app_tbs"
fi
