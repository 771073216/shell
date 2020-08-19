#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
plain='\033[0m'
TMP_DIR="$(mktemp -du)"

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

pre_install(){
    apt=$(command -v apt)
    unzip=$(command -v unzip)
    if [ -z "$unzip" ] ;then
        echo -e "[${green}Info${plain}] 正在安装unzip..."
        if [ -n "$apt" ] ;then
            apt -y install unzip
        else
            yum -y install unzip
        fi
    fi
}

set_up(){
    install -d /usr/local/etc/v2ray/
    install -d /etc/tls-shunt-proxy/
    for BASE in 00_log 01_api 02_dns 03_routing 04_policy 05_inbounds 06_outbounds 07_transport 08_stats 09_reverse; do
        echo '{}' > "/usr/local/etc/v2ray/$BASE.json"
    done
    IP=$(wget -4qO- icanhazip.com)
    uuid=$(cat /proc/sys/kernel/random/uuid)
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
    cat > /usr/local/etc/v2ray/05_inbounds.json<<-EOF
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
    ]
}
EOF
    cat > /usr/local/etc/v2ray/06_outbounds.json<<-EOF
{
        "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
    cat > /etc/tls-shunt-proxy/config.yaml<<-EOF
listen: 0.0.0.0:443
redirecthttps: 0.0.0.0:80
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
      args: /var/www
    default:
      handler: proxyPass
      args: unix:/tmp/v2ray-ds/v2ray.sock
EOF
}

check_install(){
    v2=$(pgrep -a v2ray|grep -c v2ray)
    tls=$(pgrep -a tls-shunt-proxy|grep -c tls-shunt-proxy)
    if [ "$v2" -ge 1 ] && [ "$tls" -ge 1 ] ;then
        get_update
    fi
}

install_v2(){
    echo -e "${yellow}=====================================================================${plain}"
    echo -e "[${green}Info${plain}] 开始安装${blue}V2Ray with TCP + TLS + Domain Socket${plain}"
    set_up
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    wget -cq "https://github.com/771073216/azzb/raw/master/html.zip"
    wget -cq "https://cdn.jsdelivr.net/gh/771073216/azzb/v2update.zip"
    wget -cq "https://github.com/771073216/azzb/raw/master/v2ray.service"
    unzip -oq "html.zip" -d /var/www
    unzip -oq "v2update.zip"
    install -d /usr/local/lib/v2ray/
    install -m 755 "v2ray" "v2ctl" /usr/local/bin/
    install -m 644 "geoip.dat" "geosite.dat" /usr/local/lib/v2ray/
    install -m 644 "v2ray.service" /etc/systemd/system/
    install -d -m 700 -o nobody -g nogroup /var/log/v2ray/
    systemctl enable v2ray >/dev/null 2>&1
    systemctl start v2ray
    rm -r "$TMP_DIR"
    echo -e "[${green}Info${plain}] V2Ray完成安装！"
}

install_tls(){
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    echo -e "[${green}Info${plain}] 开始安装${blue}tls-shunt-proxy${plain}..."
    wget -cq "https://cdn.jsdelivr.net/gh/771073216/afyh/tls-update.zip"
    unzip -oq "tls-update.zip"
    install -d /etc/ssl/tls-shunt-proxy/
    install -m 755 "tls-shunt-proxy" /usr/local/bin/
    if [[ -z $(id tls-shunt-proxy) ]] >/dev/null 2>&1 ;then
        useradd tls-shunt-proxy -s /usr/sbin/nologin
    fi
    wget -qP '/etc/systemd/system/' 'https://raw.githubusercontent.com/liberal-boy/tls-shunt-proxy/master/dist/tls-shunt-proxy.service'
    chown tls-shunt-proxy:tls-shunt-proxy /etc/ssl/tls-shunt-proxy
    systemctl enable tls-shunt-proxy >/dev/null 2>&1
    systemctl start tls-shunt-proxy
    rm -r "$TMP_DIR"
    echo -e "[${green}Info${plain}] ${blue}tls-shunt-proxy${plain}完成安装！"
    sleep 1
}

get_update(){
    echo -e "[${green}Info${plain}] 获取${blue}v2ray${plain}版本信息..."
    v2current=v$(/usr/local/bin/v2ray -version | grep V2Ray | cut -d' ' -f2)
    v2latest=$(wget -qO- "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4)
    [ -z "${v2latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
    if [ "${v2latest}" == "${v2current}" ]; then
        echo -e "[${green}Info${plain}] 已安装最新版本${green}${v2latest}${plain}。"
    else
        update_v2ray
    fi
    echo -e "[${green}Info${plain}] 获取${blue}tls-shunt-proxy${plain}版本信息..."
    tlscurrent=$(/usr/local/bin/tls-shunt-proxy 2>&1| grep version | cut -d' ' -f3)
    tlslatest=$(wget -qO- https://api.github.com/repos/liberal-boy/tls-shunt-proxy/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z "${tlslatest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
    if [ "${tlslatest}" == "${tlscurrent}" ]; then
        echo -e "[${green}Info${plain}] 已安装最新版本${green}${tlslatest}${plain}。"
    else
        tls_shunt_proxy_update
    fi
    exit 0
}

update_v2ray(){
    echo -e "[${green}Info${plain}] 当前版本：${red}${v2current}${plain}"
    echo -e "[${green}Info${plain}] 最新版本：${red}${v2latest}${plain}"
    echo -e "[${green}Info${plain}] 正在更新${blue}v2ray${plain}..."
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    wget -cq "https://cdn.jsdelivr.net/gh/771073216/azzb/v2update.zip"
    unzip -oq "v2update.zip"
    install -m 755 "v2ray" "v2ctl" /usr/local/bin/
    install -m 644 "geoip.dat" "geosite.dat" /usr/local/lib/v2ray/
    systemctl restart v2ray
    rm -r "$TMP_DIR"
    echo -e "[${green}Info${plain}] ${blue}v2ray${plain}更新成功！"
}

tls_shunt_proxy_update(){
    echo -e "[${green}Info${plain}] 当前版本：${red}${tlscurrent}${plain}"
    echo -e "[${green}Info${plain}] 最新版本：${red}${tlslatest}${plain}"
    echo -e "[${green}Info${plain}] 正在更新${blue}tls-shunt-proxy${plain}..."
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    wget -cq "https://cdn.jsdelivr.net/gh/771073216/afyh/tls-update.zip"
    unzip -o "tls-update.zip"
    install -m 755 "tls-shunt-proxy" /usr/local/bin/
    systemctl restart tls-shunt-proxy
    rm -r "$TMP_DIR"
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
    rm -r /tmp/v2ray-ds/
    rm -r /etc/tls-shunt-proxy/
    rm -r /usr/local/etc/v2ray/
    set_up
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    wget -cq "https://github.com/771073216/azzb/raw/master/v2ray.service"
    wget -cq "https://github.com/771073216/azzb/raw/master/html.zip"
    unzip -oq "html.zip" -d '/var/www'
    install -m 644 "v2ray.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl restart v2ray
    systemctl restart tls-shunt-proxy
    rm -r "$TMP_DIR"
    echo -e "[${green}Info${plain}] 设置成功！"
    info_v2ray
}

install_v2ray(){
    pre_install
    check_install
    if [ "$v2" -eq 0 ];then
        install_v2
    fi
    if [ "$tls" -eq 0 ];then
        install_tls
    fi
    bbr_config
    info_v2ray
}

info_v2ray(){
    if [ ! -f /usr/local/etc/v2ray/05_inbounds.json ]; then
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
    echo -e " id : ${green}$(< '/usr/local/etc/v2ray/05_inbounds.json' grep id | cut -d'"' -f4)${plain}"
    echo -e " v2ray运行状态：${v2status}"
    echo -e " tls-shunt-proxy运行状态：${tlsshuntproxy}"
}

uninstall_v2ray(){
    echo -e "[${green}Info${plain}] 正在卸载${blue}v2ray${plain}和${blue}tls-shunt-proxy${plain}..."
    systemctl disable v2ray.service >/dev/null 2>&1
    systemctl disable tls-shunt-proxy.service >/dev/null 2>&1
    systemctl stop v2ray.service tls-shunt-proxy.service
    rm /usr/local/bin/v2ray
    rm /usr/local/bin/v2ctl
    rm -r /usr/local/lib/v2ray/
    rm -r /usr/local/etc/v2ray/
    rm -r /var/log/v2ray/
    rm /etc/systemd/system/v2ray.service
    rm /etc/systemd/system/tls-shunt-proxy.service
    rm /usr/local/bin/tls-shunt-proxy
    rm -r /etc/tls-shunt-proxy/
    rm -r /tmp/v2ray-ds/
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
