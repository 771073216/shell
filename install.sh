#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

apt=$(command -v apt | grep -c apt)

pre_install(){
	unzip=$(dpkg -l | grep -c unzip)
	if [ "$unzip" -eq 0 ] ;then
		echo -e "[${green}Info${plain}] 正在安装unzip..."
	if [ "$apt" -ge 1 ] ;then
		apt -y install unzip
	else
		yum -y install unzip
	fi
	fi
}

set_up(){
	IP=$(curl -s -4 icanhazip.com)
	uuid=$(cat /proc/sys/kernel/random/uuid)
	mkdir -p '/etc/v2ray' '/etc/tls-shunt-proxy'
	echo -e -n "[${green}Info${plain}] 输入域名： "
	read -r domain
	[ -z "${domain}" ] && echo "[${red}Error${plain}] 未输入域名！" && exit 1
	host=$(host "${domain}")
	res=$(echo -n "${host}" | grep "${IP}")
	if [ -z "${res}" ]; then
		echo -e -n "[${green}Info${plain}] ${domain} 解析结果："
		host "${domain}"
		echo -e "[${red}Error${plain}] 主机未解析到当前服务器IP(${IP})!"
		exit 1
	fi
	cat > /etc/v2ray/config.json<<-EOF
{
    "inbounds": [
        {
            "protocol": "vmess",
            "listen": "127.0.0.1",
            "port": 40001,
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ds",
                "dsSettings": {
                    "path": "/tmp/v2ray-ds/v2ray.sock"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
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
	if [ "$a" -ge 1 ] && [ "$b" -ge 1 ] ;then
		get_update
	fi
}

install_v2(){
	echo -e "${yellow}=====================================================================${plain}"
	echo -e "[${green}Info${plain}] 开始安装${blue}V2Ray with TCP + TLS + Domain Socket${plain}"
	set_up
	curl -sSL -H "Cache-Control: no-cache" -O "https://github.com/771073216/azzb/releases/download/1.0/v2.zip"
	mkdir -p '/var/www/html' '/var/log/v2ray'
	unzip -q 'v2.zip' && unzip -oq "html.zip" -d '/var/www/html' && rm -rf "html.zip" "v2.zip"
	curl -sSL -H "Cache-Control: no-cache" -O "https://cdn.jsdelivr.net/gh/771073216/azzb/v2update.zip"
	unzip -ojq "v2update.zip" "v2ray" "v2ctl" "geoip.dat" "geosite.dat" -d '/usr/bin/v2ray'
	unzip -ojq "v2update.zip" "systemv/v2ray" -d '/etc/init.d'
	chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' '/etc/init.d/v2ray'
	rm -rf "v2update.zip"
	useradd v2ray -s '/usr/sbin/nologin' >/dev/null 2>&1
	chown -R v2ray:v2ray '/var/log/v2ray' >/dev/null 2>&1
	if [ "$apt" -ge 1 ] ;then
		mv "v2ray.service" '/etc/systemd/system/'
	else
		mv "v2ray.service" '/lib/systemd/system/'
	fi
	systemctl daemon-reload >/dev/null 2>&1
	update-rc.d v2ray defaults >/dev/null 2>&1
	systemctl enable v2ray.service >/dev/null 2>&1
	systemctl start v2ray.service >/dev/null 2>&1
	echo -e "[${green}Info${plain}] V2Ray完成安装！"
}

install_tls(){
	curl -sSL -H "Cache-Control: no-cache" -O "https://cdn.jsdelivr.net/gh/771073216/afyh/tls-update.zip"
	echo -e "[${green}Info${plain}] 开始安装${blue}tls-shunt-proxy${plain}..."
	unzip -ojq "tls-update.zip" -d '/usr/local/bin/'
	rm -rf tls-update.zip
	chmod +x /usr/local/bin/tls-shunt-proxy
	useradd tls-shunt-proxy -s /usr/sbin/nologin >/dev/null 2>&1
	mkdir -p '/etc/systemd/system' '/etc/ssl/tls-shunt-proxy'
	curl -sSL -H "Cache-Control: no-cache" -o '/etc/systemd/system/tls-shunt-proxy.service' 'https://raw.githubusercontent.com/liberal-boy/tls-shunt-proxy/master/dist/tls-shunt-proxy.service'
	chown tls-shunt-proxy:tls-shunt-proxy /etc/ssl/tls-shunt-proxy >/dev/null 2>&1
	systemctl enable tls-shunt-proxy.service >/dev/null 2>&1
	systemctl restart tls-shunt-proxy >/dev/null 2>&1
	echo -e "[${green}Info${plain}] ${blue}tls-shunt-proxy${plain}完成安装！"
	sleep 1
}

get_v2(){
	echo -e "[${green}Info${plain}] 获取${blue}v2ray${plain}版本信息..."
	V2VERSION=v$(/usr/bin/v2ray/v2ray -version | grep V2Ray | cut -d' ' -f2)
	V2VER=$(curl -sSL "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4)
	[ -z "${V2VER}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
	if [ "${V2VER}" == "${V2VERSION}" ]; then
		echo -e "[${green}Info${plain}] 已安装最新版本${green}${V2VER}${plain}。"
		v2=1
	fi
}

get_tls(){
	echo -e "[${green}Info${plain}] 获取${blue}tls-shunt-proxy${plain}版本信息..."
	installed_ver=$(/usr/local/bin/tls-shunt-proxy 2>&1| grep version | cut -d' ' -f3)
	latest_ver=$(curl -sSL https://api.github.com/repos/liberal-boy/tls-shunt-proxy/releases/latest | grep 'tag_name' | cut -d\" -f4)
	[ -z "${latest_ver}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
	if [ "${latest_ver}" == "${installed_ver}" ]; then
		echo -e "[${green}Info${plain}] 已安装最新版本${green}${latest_ver}${plain}。"
		tls=1
	fi
}

get_update(){
	get_v2
	get_tls
	if [[ $v2 -eq 0 ]]; then
		update_v2ray
	fi
	if [[ $tls -eq 0 ]]; then
		tls_shunt_proxy_update
	fi
	exit 0
}

update_v2ray(){
	echo -e "[${green}Info${plain}] 当前版本：${red}${V2VERSION}${plain}"
	echo -e "[${green}Info${plain}] 最新版本：${red}${V2VER}${plain}"
	echo -e "[${green}Info${plain}] 正在更新${blue}v2ray${plain}..."
	curl -sSL -H "Cache-Control: no-cache" -O "https://cdn.jsdelivr.net/gh/771073216/azzb/v2update.zip"
	unzip -ojq "v2update.zip" "v2ray" "v2ctl" "geoip.dat" "geosite.dat" -d '/usr/bin/v2ray'
	unzip -ojq "v2update.zip" "systemv/v2ray" -d '/etc/init.d'
	chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' '/etc/init.d/v2ray'
	rm -rf "v2update.zip"
	systemctl restart v2ray
	echo -e "[${green}Info${plain}] ${blue}v2ray${plain}更新成功！"
}

tls_shunt_proxy_update(){
	echo -e "[${green}Info${plain}] 当前版本：${red}${installed_ver}${plain}"
	echo -e "[${green}Info${plain}] 最新版本：${red}${latest_ver}${plain}"
	echo -e "[${green}Info${plain}] 正在更新${blue}tls-shunt-proxy${plain}..."
	curl -sSL -H "Cache-Control: no-cache" -o "update.zip" "https://cdn.jsdelivr.net/gh/771073216/afyh/tls-update.zip"
	unzip -qjo "update.zip" -d '/usr/local/bin/'
	rm -rf "update.zip"
	chmod +x /usr/local/bin/tls-shunt-proxy
	systemctl restart tls-shunt-proxy
	echo -e "[${green}Info${plain}] ${blue}tls-shunt-proxy${plain}更新成功！"
}

bbr_config() {
	echo -e "[${green}Info${plain}] 设置bbr..."
	sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
	sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
	( echo "net.core.default_qdisc = fq"
	echo "net.ipv4.tcp_congestion_control = bbr" ) >> '/etc/sysctl.conf'
	sysctl -p >/dev/null 2>&1
}

config_v2ray(){
	set_up
	curl -sSL -H "Cache-Control: no-cache" -O "https://github.com/771073216/azzb/releases/download/1.0/v2.zip"
	mkdir -p '/var/www/html'
	unzip -q "v2.zip" && unzip -oq "html.zip" -d '/var/www/html' && rm -rf "html.zip" "v2.zip"
	if [ "$apt" -ge 1 ] ;then
		mv "v2ray.service" '/etc/systemd/system/'
	else
		mv "v2ray.service" '/lib/systemd/system/'
	fi
	systemctl daemon-reload
	systemctl restart v2ray
	systemctl restart tls-shunt-proxy
	echo -e "[${green}Info${plain}] 设置成功！"
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
	info_v2ray
}

info_v2ray(){
	if [ ! -f /etc/v2ray/config.json ]; then
		echo -e "[${red}Error${plain}] 未找到V2Ray配置文件！" && exit 1
	fi
	if [ ! -f /etc/tls-shunt-proxy/config.yaml ]; then
		echo -e "[${red}Error${plain}] 未找到tls-shunt-proxy配置文件！" && exit 1
	fi
	status=$(pgrep -a v2ray|grep -c v2ray)
	tlsstatus=$(pgrep -a tls-shunt-proxy|grep -c tls-shunt-proxy)
	v2status="${green}正在运行${plain}"
	if [ "$status" -eq 0 ] ;then
		v2status="${red}已停止${plain}"
	fi
	tlsshuntproxy="${green}正在运行${plain}"
	if [ "$tlsstatus" -eq 0 ] ;then
		tlsshuntproxy="${red}已停止${plain}"
	fi
	echo -e "id : ${green}$(< '/etc/v2ray/config.json' grep id | cut -d'"' -f4)${plain}"
	echo -e " v2ray运行状态：${v2status}"
	echo -e " tls-shunt-proxy运行状态：${tlsshuntproxy}"
}

uninstall_v2ray(){
	echo -e "[${green}Info${plain}] 正在卸载${blue}v2ray${plain}和${blue}tls-shunt-proxy${plain}..."
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
	echo -e "[${green}Info${plain}] 卸载成功！"
}

# Initialization step
action=$1
[ -z "$1" ] && action=install
case "$action" in
    install|uninstall|config|info)
	${action}_v2ray
	;;
    *)
	echo "参数错误！ [${action}]"
	echo "使用方法：$(basename "$0") [install|uninstall|config|info]"
	;;
esac
