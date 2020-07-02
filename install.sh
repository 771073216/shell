#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

apt=$(command -v apt | grep -c apt)

pre_install(){
	d=$(dpkg -l | grep -c unzip)
	if [ "$d" -eq 0 ] ;then
	echo -e "[${green}Info${plain}] Installing unzip..."
	if [ "$apt" -eq 1 ] ;then
	apt -y install unzip
	else
	yum -y install unzip
	fi
	fi
}

set_up(){
	mkdir -p '/etc/v2ray' '/etc/tls-shunt-proxy'
	uuid=$(cat /proc/sys/kernel/random/uuid)
	echo -e "[${green}Info${plain}] Please input domain:"
	read -r -p "Your domain : " domain
	[ -z "${domain}" ] && echo "[${red}Error${plain}] Miss domain" && exit 1
	cat > /etc/v2ray/config.json<<-EOF
{
	"inbounds": [{
		"protocol": "vmess",
		"listen": "127.0.0.1",
		"port": 40001,
		"settings": {
			"clients": [{
				"id": "${uuid}"
			}]
		},
		"streamSettings": {
			"network": "ds",
			"dsSettings": {
				"path": "/tmp/v2ray-ds/v2ray.sock"
			}

		}
	}],
	"outbounds": [{
		"protocol": "freedom"
	}]
}
EOF
	cat > /etc/tls-shunt-proxy/config.yaml<<-EOF
listen: 0.0.0.0:443
inboundbuffersize: 4
outboundbuffersize: 32
vhosts:
  - name: ${domain}
    tlsoffloading: true
    managedcert: true
    alpn: h2,http/1.1
    protocols: tls12,tls13
    http:
      handler: fileServer
      args: /var/www/html
    default:
      handler: proxyPass
      args: unix:/tmp/v2ray-ds/v2ray.sock
EOF
}

check_install(){
	a=$(pgrep -a v2ray|grep -c v2ray)
	b=$(pgrep -a tls-shunt-proxy|grep -c tls-shunt-proxy)
	((c=a+b-2))
	if [ $c -ge 0 ] ;then
	get_update
	fi
}

install_v2(){
	echo -e "${yellow}=====================================================================${plain}"
	echo -e "[${green}Info${plain}] Start to install ${blue}V2Ray with TCP + TLS + Domain Socket${plain}"
	sleep 1
	set_up
	echo -e "[${green}Info${plain}] Downloading..."
	curl -sSL -H "Cache-Control: no-cache" -O "https://github.com/771073216/azzb/releases/download/1.0/v2.zip"
	mkdir -p '/var/www/html' '/var/log/v2ray'
	unzip -q 'v2.zip' && unzip -oq "html.zip" -d '/var/www/html' && rm -rf "html.zip" "v2.zip"
	curl -sSL -H "Cache-Control: no-cache" -O "https://cdn.jsdelivr.net/gh/771073216/azzb/v2update.zip"
	unzip -ojq "v2update.zip" "v2ray" "v2ctl" "geoip.dat" "geosite.dat" -d '/usr/bin/v2ray'
	unzip -ojq "v2update.zip" "systemv/v2ray" -d '/etc/init.d'
	chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' '/etc/init.d/v2ray'
	rm -rf "v2update.zip"
	echo -e "[${green}Info${plain}] Extract ${blue}v2ray${plain} successfully!"
	sleep 1
	echo -e "[${green}Info${plain}] Configure ${blue}Domain Socket${plain}..."
	useradd v2ray -s '/usr/sbin/nologin' >/dev/null 2>&1
	chown -R v2ray:v2ray '/var/log/v2ray' >/dev/null 2>&1
	if [ "$apt" -eq 1 ] ;then
	mv "v2ray.service" '/etc/systemd/system/'
	else
	mv "v2ray.service" '/lib/systemd/system/'
	fi
	systemctl daemon-reload >/dev/null 2>&1
	update-rc.d v2ray defaults >/dev/null 2>&1
	systemctl enable v2ray.service >/dev/null 2>&1
	systemctl start v2ray.service >/dev/null 2>&1
	echo -e "[${green}Info${plain}] Configure ${blue}Domain Socket${plain} successfully!"
	sleep 1
}

install_tls(){
	echo -e "[${green}Info${plain}] Download and install ${blue}tls-shunt-proxy${plain}..."
	curl -sSL -H "Cache-Control: no-cache" -O "https://cdn.jsdelivr.net/gh/771073216/afyh/tls-update.zip"
	unzip -ojq "tls-update.zip" -d '/usr/local/bin/'
	rm -rf tls-update.zip
	chmod +x /usr/local/bin/tls-shunt-proxy
	useradd tls-shunt-proxy -s /usr/sbin/nologin >/dev/null 2>&1
	mkdir -p '/etc/systemd/system' '/etc/ssl/tls-shunt-proxy'
	curl -sSL -H "Cache-Control: no-cache" -o '/etc/systemd/system/tls-shunt-proxy.service' 'https://raw.githubusercontent.com/liberal-boy/tls-shunt-proxy/master/dist/tls-shunt-proxy.service'
	chown tls-shunt-proxy:tls-shunt-proxy /etc/ssl/tls-shunt-proxy >/dev/null 2>&1
	systemctl enable tls-shunt-proxy.service >/dev/null 2>&1
	systemctl restart tls-shunt-proxy >/dev/null 2>&1
	echo -e "[${green}Info${plain}] Install ${blue}tls-shunt-proxy${plain} successfully!"
	sleep 1
}

get_update(){
	echo -e "[${green}Info${plain}] Get ${blue}v2ray${plain} latest version..."
	V2VER=$(curl -H "Accept: application/json" -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:74.0) Gecko/20100101 Firefox/74.0" -sS "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" --connect-timeout 10| grep 'tag_name' | cut -d\" -f4)
	[ -z "${V2VER}" ] && echo -e "[${red}Error${plain}] Get ${blue}v2ray${plain} latest version failed" && exit 0
	V2VERSION=v$(/usr/bin/v2ray/v2ray -version | grep V2Ray | cut -d' ' -f2)
	if [ "${V2VER}" == "${V2VERSION}" ]; then
	echo -e "[${green}Info${plain}] Latest version ${green}${V2VER}${plain} has already been installed."
	v2=1
	fi
	echo -e "[${green}Info${plain}] Get ${blue}tls-shunt-proxy${plain} version..."
	latest_ver=$(curl -sSL https://api.github.com/repos/liberal-boy/tls-shunt-proxy/releases/latest | grep 'tag_name' | cut -d\" -f4)
	[ -z "${latest_ver}" ] && echo -e "[${red}Error${plain}] Get ${blue}tls-shunt-proxy${plain} latest version failed" && exit 0
	installed_ver=$(/usr/local/bin/tls-shunt-proxy 2>&1| grep version | cut -d' ' -f3)
	if [ "${latest_ver}" == "${installed_ver}" ]; then
	echo -e "[${green}Info${plain}] Latest version ${green}${latest_ver}${plain} has already been installed."
	tls=1
	fi
	if [ $v2 -eq 0 ]; then
	update_v2ray
	fi
	if [ $tls -eq 0 ]; then
	tls_shunt_proxy_update
	fi
	exit 0
}

update_v2ray(){
	echo -e "[${green}Info${plain}] Installed version: ${red}${V2VERSION}${plain}"
	echo -e "[${green}Info${plain}] Latest version: ${red}${V2VER}${plain}"
	echo -e "[${green}Info${plain}] Update ${blue}v2ray${plain} to latest version..."
	curl -sSL -H "Cache-Control: no-cache" -O "https://cdn.jsdelivr.net/gh/771073216/azzb/v2update.zip"
	unzip -ojq "v2update.zip" "v2ray" "v2ctl" "geoip.dat" "geosite.dat" -d '/usr/bin/v2ray'
	chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl'
	rm -rf "v2update.zip"
	systemctl restart v2ray
	echo -e "[${green}Info${plain}] Update ${blue}v2ray${plain} successfully!"
}

tls_shunt_proxy_update(){
	echo -e "[${green}Info${plain}] Installed version: ${red}${installed_ver}${plain}"
	echo -e "[${green}Info${plain}] Latest version: ${red}${latest_ver}${plain}"
	echo -e "[${green}Info${plain}] Update ${blue}tls-shunt-proxy${plain} to latest version..."
	curl -sSL -H "Cache-Control: no-cache" -o "update.zip" "https://cdn.jsdelivr.net/gh/771073216/afyh/tls-update.zip"
	unzip -qjo "update.zip" -d '/usr/local/bin/'
	rm -rf "update.zip"
	systemctl restart tls-shunt-proxy
	echo -e "[${green}Info${plain}] Update ${blue}tls-shunt-proxy${plain} successfully!"
}

bbr_config() {
	echo -e "[${green}Info${plain}] Setting up bbr..."
	sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
	sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
	( echo "net.core.default_qdisc = fq"
	echo "net.ipv4.tcp_congestion_control = bbr" ) >> '/etc/sysctl.conf'
	sysctl -p >/dev/null 2>&1
	sleep 1
}

config_v2ray(){
	set_up
	curl -sSL -H "Cache-Control: no-cache" -O "https://github.com/771073216/azzb/releases/download/1.0/v2.zip"
	mkdir -p '/var/www/html'
	unzip -q "v2.zip" && unzip -oq "html.zip" -d '/var/www/html' && rm -rf "html.zip" "v2.zip"
	if [ "$apt" -eq 1 ] ;then
	mv "v2ray.service" '/etc/systemd/system/'
	else
	mv "v2ray.service" '/lib/systemd/system/'
	fi
	echo -e "[${green}Info${plain}] Restarting ${blue}v2ray${plain} and ${blue}tls-shunt-proxy${plain} services"
	systemctl daemon-reload
	systemctl restart v2ray
	systemctl restart tls-shunt-proxy
	echo -e "[${green}Info${plain}] Configure success!"
	echo -e "id : ${green}$(< '/etc/v2ray/config.json' grep id | cut -d'"' -f4)${plain}"
}

install_v2ray(){
	pre_install
	check_install
	if [ "$a" -eq 0 ];then
	install_v2
	fi
	if [ "$b" -eq 0 ];then
	install_tls
	fi
	bbr_config
	echo -e "id : ${green}$(< '/etc/v2ray/config.json' grep id | cut -d'"' -f4)${plain}"
}

uninstall_v2ray(){
	echo -e "[${green}Info${plain}] Uninstall ${blue}v2ray${plain} and ${blue}tls-shunt-proxy${plain}..."
	systemctl disable v2ray.service >/dev/null 2>&1
	systemctl disable tls-shunt-proxy.service >/dev/null 2>&1
	systemctl stop v2ray.service tls-shunt-proxy.service >/dev/null 2>&1
	rm -rf '/etc/init.d/v2ray' '/etc/v2ray'
	rm -rf "/etc/systemd/system/v2ray.service"
	rm -rf "/lib/systemd/system/v2ray.service"
	rm -rf '/etc/tls-shunt-proxy'
	rm -rf "/etc/systemd/system/tls-shunt-proxy.service"
	rm -rf "/usr/local/bin/tls-shunt-proxy"
	rm -rf "/etc/systemd/system/multi-user.target.wants/tls-shunt-proxy.service"
	rm -rf '/tmp/v2ray-ds'
	sleep 1
	echo -e "[${green}Info${plain}] Remove config manually if it necessary."
	echo -e "[${green}Info${plain}] Uninstall success!"
}

# Initialization step
action=$1
[ -z "$1" ] && action=install
case "$action" in
    install|uninstall|config)
	${action}_v2ray
	;;
    *)
	echo "Arguments error! [${action}]"
	echo "Usage: $(basename "$0") [install|uninstall|config]"
	;;
esac
