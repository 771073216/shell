#!/bin/bash
num1=0
num2=0
list1=$(find /data/data/ -name app_tbs)
list2=$(find /data/data/ -name app_tbs_64)
for file in $list1; do
  if find "${file}"/* 2> /dev/null; then
    rm -r "${file:?}"/*
    chattr -i "$file"
    chmod 000 "$file"
    num1=$((num1 + 1))
    echo "delete $file"
  fi
done
for file in $list2; do
  if find "${file}"/* 2> /dev/null; then
    rm -r "${file:?}"/*
    chattr -i "$file"
    chmod 000 "$file"
    num2=$((num2 + 1))
    echo "delete $file"
  fi
done
sum=$((num1 + num2))
if [ $sum -eq 0 ]; then
  echo "everything is clean"
fi
if [ $num1 -ne 0 ]; then
  echo "clean $num1 app_tbs"
fi
if [ $num2 -ne 0 ]; then
  echo "clean $num2 app_tbs_64"
fi
