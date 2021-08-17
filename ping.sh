#!/bin/sh
main(){
list="sp kr tk os"
echo "testing"
for p in $list; do
{
  $p
  } &
done
wait
}

kr(){
ip="13.124.63.251"
test $ip "korea"
}

tk(){
ip="13.208.32.253"
test $ip "tokyo"
}

os(){
ip="18.182.0.0"
test $ip "osaka"
}

sp(){
test "13.250.0.253" "singapore"
}

test(){
a=$(ping -c 200 -W 1 $1 | tail -n2)
loss=$(echo $a | awk '/loss/ {print$7}')
round=$(echo $a | awk '{print$11" "$13$14}')
echo "aws $2: loss $loss   $round"
}

main
