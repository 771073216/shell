#!/bin/sh
i=0
for dir in $(cmd package list package -3 | awk -F':' '{print$2}'); do
  if find /data/data/"$dir"/app_tbs > /dev/null 2>&1; then
    if [ -n "$(ls /data/data/"$dir"/app_tbs* | grep -v :)" ]; then
      rm -rf /data/data/"$dir"/app_tbs*/*
      chattr -i /data/data/"$dir"/app_tbs*
      chmod 000 /data/data/"$dir"/app_tbs*
      echo "Clean $dir..."
      i=$((i + 1))
    fi
  fi
done

if [ "$i" -eq 0 ]; then
  echo "Everything is clean."
fi
