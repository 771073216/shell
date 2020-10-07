#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
file=/var/log/ss.log
start=$(awk < "$file" 'NR==1{print$1,$2,$3}')
end=$(awk < "$file" 'END{print$1,$2,$3}')
list=$(grep < "$file" established | awk -F'[]:]+' '{print$10}' | sort | uniq -c | sort -r)
count=$(grep < "$file" -c crypto_io)
starttime=$(grep < "$file" crypto_io | head -n 1 | awk '{print$1,$2,$3}')
cryptoerror=$(grep < "$file" -c 'AEAD decrypt error')
udp=$(grep < "$file" -c 'finished')
month=$(date "+%Y-%m")
data=$(vnstat -s | grep "$month" | awk '{print$5,$6}')
todaydata=$(vnstat -s | grep "today" | awk '{print$5,$6}')
list2=$(grep < "$file" finished | awk -F'[]:]+' '{print$10}' | sort | uniq -c | sort -r)
def() {
  if [ -n "$list" ]; then
    echo -e "${green}$start --> $end${plain}"
  fi
  if [ -n "$starttime" ]; then
    echo -ne "${yellow}detected repeated attack:$count${plain}   "
    echo -e "${red}start at $starttime${plain}"
  else
    echo -e "${yellow}detected repeated attack:$count${plain}   "
  fi
  echo -e "${yellow}AEAD decrypt failed:$cryptoerror${plain}"
  echo -e "${green}today TX data:$todaydata${plain}"
  echo -e "${green}month TX data:$data${plain}"
  echo -e "${green}udp connection:$udp${plain}"
  if [[ "$udp" -gt 0 ]]; then
    udptrafficrx=$(($(grep < "$file" 'payload' | grep '<' | grep -v 'message repeated' | awk -F'length' '{print$2}' | awk '{print$1}' | awk '{sum +=$1};END {print sum}') / 1024))
    echo -e "${green}udp RX traffic:$udptrafficrx Kb${plain}"
  fi
  if [ -z "$list" ]; then
    echo "no connection"
  else
    echo "-----------------------------"
    echo -e "         ${green}tcp${plain}"
    echo " counts      ip"
    echo "$list       "
    echo -e "         ${green}udp${plain}"
    echo " counts      ip"
    echo "$list2"
    echo "------------------------------"
  fi
}

q() {
  def
  echo -n "which tcp:"
  read -r ip
  if [ -z "$ip" ]; then
    exit 0
  fi
  tcp=$(echo "$list" | head -n "$ip" | tail -n 1 | awk '{print$2}')
  locate=$(curl -sSL http://freeapi.ipip.net/"$tcp" | awk -F'["]' '{print$2,$4,$6,$8,$10}')
  echo -e "${yellow}$tcp   $locate${plain}"
  #grep < "$file" "$ip"
}

l() {
  cat "$file"
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
