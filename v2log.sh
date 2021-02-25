#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
file=/var/log/xray/access.log
list=$(grep < "$file" shadowsocks | grep -v udp: | grep accepted | awk -F'[ :]' '{print$5}' | sort | uniq -c | sort -r)
rejected=$(grep < "$file" -c rejected)
replyatk=$(grep < "$file" -c 'failed to read IV')
cryptoerror=$(grep < "$file" -c 'failed to read address')
month=$(date "+%Y-%m")
data=$(vnstat -s | grep "$month" | awk '{print$5,$6}')
todaydata=$(vnstat -s | grep "today" | awk '{print$5,$6}')
def() {
  echo -ne "${yellow}detected repeated attack:$replyatk${plain}   "
  echo -e "${yellow}AEAD decrypt failed:$cryptoerror${plain}"
  echo -e "${yellow}connects rejected:$rejected${plain}"
  echo -e "${green}today TX data:$todaydata${plain}"
  echo -e "${green}month TX data:$data${plain}"
  if [ -z "$list" ]; then
    echo "no connection"
  else
    echo "-----------------------------"
    echo -e "         ${green}tcp${plain}"
    echo " counts      ip"
    echo "$list       "
    echo "------------------------------"
  fi
DATA=$(apidata $1)
print_sum "$DATA"
echo "-----------------------------"
}

apidata () {
    xray api statsquery -s 127.0.0.1:10085 \
    | awk '{
        if (match($1, /name/)) {
            f=1; gsub(/^"|link.*$/, "", $2);
            split($2, p,  ">>>");
            printf "%s->%s\t", p[2],p[4];
        }
        else if (match($1, /value/) && f){ f = 0; printf "%.0f\n", $2; }
        else if (match($0, /^{|}.*$/) && f) { f = 0; print 0; }
    }'
}
print_sum() {
    DATA="$1"
    PREFIX="$2"
    SORTED=$(echo "$DATA" | grep "^${PREFIX}" | sort -r)
    SUM=$(echo "$SORTED" | awk '
        /->up/{us+=$2}
        /->down/{ds+=$2}
        END{
            printf "SUM->up:\t%.0f\nSUM->down:\t%.0f\nSUM->TOTAL:\t%.0f\n", us, ds, us+ds;
        }')
    echo -e "${SORTED}\n${SUM}" \
    | numfmt --field=2 --suffix=B --to=iec \
    | column -t
}


q() {
  echo "$list"
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
  echo "$list"
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

w(){
  echo "$list"
  echo -n "ip:"
  read -r ip
  if [ -z "$ip" ]; then
    exit 0
  fi
  tcp=$(echo "$list" | head -n "$ip" | tail -n 1 | awk '{print$2}')
  grep < "$file" $tcp | grep -v udp: | awk -F':' '{print$5}' | sort | uniq -c | sort -n
}

t() {
  tail -f "$file"
}

action=$1
[ -z "$1" ] && action=def
case "$action" in
  def | q | l | b | t | w)
    $action
    ;;
  *) ;;
esac
