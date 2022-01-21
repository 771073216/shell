#!/bin/sh
i=0
num=$(cmd package list package -a | awk -F':' '{print$2}' | grep -c "")
for package in $(cmd package list package -a | awk -F':' '{print$2}'); do
  i=$((i + 1))
  echo "$i/$num $package"
  cmd package compile -m speed "$package" > /dev/null
done

i=0
num=$(cmd package list package -a | awk -F':' '{print$2}' | grep -xv android | grep -c "")
for package in $(cmd package list package -a | awk -F':' '{print$2}' | grep -xv android); do
  i=$((i + 1))
  echo "$i/$num $package"
  cmd package compile -m speed "$package" --secondary-dex > /dev/null
done
