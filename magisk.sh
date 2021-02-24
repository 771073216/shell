#!/usr/bin/env bash
wget -qO- https://raw.githubusercontent.com/topjohnwu/magisk_files/master/stable.json > /var/www/magisk/stable.json
ver=$(awk -F'"' 'NR==3{print$4}' /var/www/magisk/stable.json)
vercode=$(awk -F'"' 'NR==4{print$4}' /var/www/magisk/stable.json)
ver1=$(awk -F'"' 'NR==9{print$4}' /var/www/magisk/stable.json)
md5=$(awk -F'"' 'NR==20{print$4}' /var/www/magisk/stable.json)
local=$(awk -F'"' 'NR==3{print$4}' /var/www/magisk/repo.json)
if ! [ "${ver}" == "${local}" ]; then
  rm /var/www/magisk/stub-release.apk
  rm /var/www/magisk/Magisk-v"$local".apk
  wget -P /var/www/magisk https://github.com/topjohnwu/Magisk/releases/download/v"$ver"/Magisk-v"$ver".apk
  wget -P /var/www/magisk https://github.com/topjohnwu/Magisk/releases/download/v"$ver"/stub-release.apk
  cat > /var/www/magisk/repo.json <<- EOF
{
  "app": {
    "version": "$ver",
    "versionCode": "$vercode",
    "link": "https://www.azzb.club/magisk/Magisk-v$ver.apk",
    "note": "https://topjohnwu.github.io/Magisk/releases/$vercode.md"
  },
  "stub": {
    "versionCode": "$ver1",
    "link": "https://www.azzb.club/magisk/stub-release.apk"
  },
  "uninstaller": {
    "link": "https://www.azzb.club/magisk/21.4/Magisk-uninstaller-20210117.zip"
  },
  "magisk": {
    "version": "$ver",
    "versionCode": "$vercode",
    "link": "https://www.azzb.club/magisk/Magisk-v$ver.apk",
    "note": "https://topjohnwu.github.io/Magisk/releases/$vercode.md",
    "md5": "$md5"
  }
}
EOF
fi
