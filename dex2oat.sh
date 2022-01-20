#!/bin/sh
i=0
num=$(cmd package list package -a | awk -F':' '{print$2}' | grep -c "")
for package in $(cmd package list package -a | awk -F':' '{print$2}'); do
  i=$((i + 1))
  cmd package compile -m speed "$package" > /dev/null
  echo "$i/$num $package"
done

i=0
num=$(cmd package list package -a | awk -F':' '{print$2}' | grep -xv android | grep -c "")
for package in $(cmd package list package -a | awk -F':' '{print$2}' | grep -xv android); do
  i=$((i + 1))
  cmd package compile -m speed "$package" --secondary-dex > /dev/null
  echo "$i/$num $package"
done
