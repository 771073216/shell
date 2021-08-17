#!/bin/sh
main() {
  list="sp kr tk os"
  time=$(date "+%d%H")
  ltime=$(date)
  old=$(("$time" - 100))
  rm -f $old.log
  echo "" > /root/"$time".log
  echo "$ltime" >> /root/"$time".log
  for p in $list; do
    {
      $p
    } &
  done
  wait
}

kr() {
  test "13.124.63.251" "korea"
}

tk() {
  test "13.208.32.253" "tokyo"
}

os() {
  test "18.182.0.0" "osaka"
}

sp() {
  test "13.250.0.253" "singapore"
}

test() {
  a=$(ping -c 200 -W 1 "$1" | tail -n2)
  loss=$(echo "$a" | awk '/loss/ {print$7}')
  round=$(echo "$a" | awk '{print$11" "$13$14}')
  printf "%-15s%-10s%-20s\n" "$2:" "loss $loss" "$round" >> /root/"$time".log
}

main
