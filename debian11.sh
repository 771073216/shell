#!/usr/bin/env bash
path="/etc/apt/sources.list"
cp $path $path.bak
if grep security $path > /dev/null; then
  sed -i '/security/d' $path
  echo "deb http://security.debian.org/debian-security stable-security main" >> $path
fi
link=$(grep -v "security\|#" $path | awk '/deb/ {print$2}' | uniq)
ver=$(grep -v "updates\|backports\|security\|#" $path | awk '/deb/ {print$3}' | uniq)
if grep backports $path > /dev/null; then
  backports=$(wget -qO- "$link"/dists/stable-backports/InRelease | awk '/Suite/ {print$2}')
  sed -i "s/$ver-backports/$backports/g" $path
fi
sed -i "s/$ver/stable/g" $path
