#!/usr/bin/env bash
wget -qO- https://raw.githubusercontent.com/topjohnwu/magisk_files/master/stable.json > /var/www/magisk/stable.json
cp /var/www/magisk/stable.json /var/www/magisk/repo.json
appfile=$(grep MagiskManager < /var/www/magisk/stable.json | awk -F'[/"]' '{print$12}')
magiskfile=$(grep Magisk-v < /var/www/magisk/stable.json | awk -F'[/"]' '{print$12}')
magiskun=$(grep Magisk-uninstaller < /var/www/magisk/stable.json | awk -F'[/"]' '{print$12}')
localmagisk=$(basename /var/www/magisk/Magisk-v*)
localapp=$(basename /var/www/magisk/MagiskM*)
link1=$(grep link < /var/www/magisk/stable.json | grep MagiskManager | awk -F'"' '{print$4}')
link2=$(grep link < /var/www/magisk/stable.json | grep stub-release | awk -F'"' '{print$4}')
link3=$(grep link < /var/www/magisk/stable.json | grep Magisk-uninstaller | awk -F'"' '{print$4}')
link4=$(grep link < /var/www/magisk/stable.json | grep Magisk-v | awk -F'"' '{print$4}')
t1=$(grep -n MagiskManager /var/www/magisk/stable.json | awk -F':' '{print $1}')
t2=$(grep -n stub-release /var/www/magisk/stable.json | awk -F':' '{print $1}')
t3=$(grep -n Magisk-uninstaller /var/www/magisk/stable.json | awk -F':' '{print $1}')
t4=$(grep -n Magisk-v /var/www/magisk/stable.json | awk -F':' '{print $1}')
dl1=https://www.azzb.club/magisk/$appfile
dl2=https://www.azzb.club/magisk/stub-release.apk
dl3=https://www.azzb.club/magisk/$magiskun
dl4=https://www.azzb.club/magisk/$magiskfile
if ! [ "${appfile}" == "${localapp}" ]; then
rm /var/www/magisk/stub-release.apk
rm /var/www/magisk/MagiskManager*
wget -q --show-progress -P /var/www/magisk "$link1"
wget -q --show-progress -P /var/www/magisk "$link2"
fi
if ! [ "${magiskfile}" == "${localmagisk}" ]; then
rm /var/www/magisk/Magisk-*
wget -q --show-progress -P /var/www/magisk "$link3"
wget -q --show-progress -P /var/www/magisk "$link4"
fi
sed -i ''"$t1"'c "link": "'"$dl1"'",' /var/www/magisk/repo.json
sed -i ''"$t2"'c "link": "'$dl2'"' /var/www/magisk/repo.json
sed -i ''"$t3"'c "link": "'"$dl3"'"' /var/www/magisk/repo.json
sed -i ''"$t4"'c "link": "'"$dl4"'",' /var/www/magisk/repo.json
