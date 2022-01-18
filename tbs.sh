#!/bin/sh
for dir in $(cmd package list package -3 | awk -F':' '{print$2}'); do
  if find /data/data/$dir/app_tbs > /dev/null 2>&1; then
    rm -rf /data/data/$dir/app_tbs*/*
    chattr -i /data/data/$dir/app_tbs*
    chmod 000 /data/data/$dir/app_tbs*
    echo "Clean $dir"
  fi
done