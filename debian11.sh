#!/usr/bin/env bash
path="/etc/apt/sources.list"
cp $path $path.bak
if grep security $path > /dev/null; then
  sed -i '/security/d' $path
  echo "deb http://security.debian.org/debian-security stable-security main" >> $path
  echo "deb-src http://security.debian.org/debian-security stable-security main" >> $path
fi
link=$(awk '{print$2}' $path | grep -v "security" | uniq)
ver=$(awk '{print$3}' $path | grep -v "updates\|backports\|security" | uniq)
backports=$(curl -sSL "$link"/dists/stable-backports/InRelease | awk '/Suite/ {print$2}')
sed -i "s/$ver-backports/$backports/g" $path
sed -i "s/$ver/stable/g" $path
