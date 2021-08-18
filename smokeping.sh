#!/usr/bin/env bash
docker pull linuxserver/smokeping
mkdir -p /data/smokeping/data/ /data/smokeping/config/
docker run --name rpi -d --hostname rpi --restart unless-stopped -p 80:80 -e TZ=Asia/Shanghai -v /data/smokeping/data:/data -v /data/smokeping/config:/config linuxserver/smokeping
