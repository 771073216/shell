#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
file=/var/log/ss.log
start=$(awk < "$file" 'NR==1{print$1,$2,$3}')
end=$(awk < "$file" 'END{print$1,$2,$3}')
list=$(grep < "$file" RELAY | awk -F'[]:]+' '{print$10}' | sort | uniq -c | sort -r)
count=$(grep < "$file" -c crypto_io)
starttime=$(grep < "$file" crypto_io | head -n 1 | awk '{print$1,$2,$3}')
countip=$(grep < "$file" -c 'failed to decode Address')
cryptoerror=$(grep < "$file" -c 'AEAD decrypt error')
((failed = "$countip" - "$count"))
def() {
  echo -e "${green}$start --> $end${plain}"
  if [ -n "$starttime" ]; then
    echo -ne "${yellow}replay attack count:$count${plain}   "
    echo -e "${red}start at $starttime${plain}"
  else
    echo -e "${yellow}replay attack count:$count${plain}   "
  fi
  echo -e "${yellow}connect failed count:$failed${plain}"
  echo -e "${yellow}crypto failed count:$cryptoerror${plain}"
  if [ -z "$list" ]; then
    echo "no ip connected"
  else
    echo -e "${green}      connected ip list     ${plain}"
    echo "------------------------------"
    echo " counts      ip"
    echo "$list"
    echo "------------------------------"
    num=$(echo "$list" | wc -l)
    bom=$(echo "$list" | head -n "$num" | tail -n 1 | awk '{print$1}')
    if [ "$bom" -lt 10 ]; then
      echo -e "${yellow}low connects ip${plain}"
      qwe
    fi
  fi
}

q() {
  def
  echo -n "ip:"
  read -r ip
  if [ -z "$ip" ]; then
    exit 0
  fi
  locate=$(curl -sSL http://freeapi.ipip.net/"$ip" | awk -F'["]' '{print$2,$4,$6,$8,$10}')
  echo -e "${yellow}$ip   $locate${plain}"
  #  grep < "$file" "$ip"
}

l() {
  cat "$file"
}

qwe() {
  for ((i = 1; i < "$num"; i++)); do
    test=$(echo "$list" | head -n "$i" | tail -n 1 | awk '{print$1}')
    if [ "$test" -lt 10 ]; then
      ip=$(echo "$list" | head -n "$i" | tail -n 1 | awk '{print$2}')
      echo "$ip"
    fi
  done
}

b() {
  def
  echo -n "ip:"
  read -r ip
  echo -n "1:ban 2:unban"
  read -r ban
  if [ -z "$ip" ]; then
    exit 0
  fi
  if [ "$ban" -eq 1 ]; then
    ufw reject from "$ip"
    ufw reject to "$ip"
  fi
  if [ "$ban" -eq 2 ]; then
    ufw delete reject from "$ip"
    ufw delete reject to "$ip"
  fi
  b
}

t() {
  tail -f "$file"
}

action=$1
[ -z "$1" ] && action=def
case "$action" in
  def | q | l | b | t)
    $action
    ;;
  *) ;;
esac
