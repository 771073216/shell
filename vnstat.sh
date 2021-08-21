#!/usr/bin/env bash
apt install -y build-essential libsqlite3-dev git
git clone https://github.com/vergoh/vnstat.git && cd vnstat || exit 1
./configure --prefix=/usr --sysconfdir=/etc && make && make install
cp examples/systemd/vnstat.service /etc/systemd/system/
systemctl enable vnstat.service --now
cd .. && rm -r vnstat
