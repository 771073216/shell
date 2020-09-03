#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

TMP_DIR="$(mktemp -du)"
v2=$(pgrep -a v2ray|grep -c v2ray)
v2link=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
tsplink=https://github.com/liberal-boy/tls-shunt-proxy/releases/latest/download/tls-shunt-proxy-linux-amd64.zip

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

config_v2ray(){
    rm -rf /tmp/v2ray-ds/
    rm -rf /usr/local/etc/v2ray/
    install -d /usr/local/etc/v2ray/
    install -d /etc/tls-shunt-proxy/
    wget -cq "https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip"
    unzip -oq "html.zip" -d '/var/www'
    rm -f html.zip
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
    set_v2
    set_tsp
    set_service
    set_bbr
    systemctl daemon-reload
    systemctl restart v2ray
    systemctl restart tls-shunt-proxy
    info_v2ray
}

set_v2(){
    cat > /usr/local/etc/v2ray/config.json<<-EOF
{
    "inbounds": [
        {
            "protocol": "vmess",
            "listen": "127.0.0.1",
            "port": 40001,
            "settings": {
                "clients": [
                    {
                        "id": "$uuid"
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
}

set_tsp(){
    cat > /etc/tls-shunt-proxy/config.yaml<<-EOF
listen: 0.0.0.0:443
redirecthttps: 0.0.0.0:80
inboundbuffersize: 4
outboundbuffersize: 32
vhosts:
  - name: $domain
    tlsoffloading: true
    managedcert: true
    alpn: h2
    protocols: tls13
    http:
      handler: fileServer
      args: /var/www
    default:
      handler: proxyPass
      args: unix:/tmp/v2ray-ds/v2ray.sock
EOF
}

set_service(){
    cat > /etc/systemd/system/v2ray.service<<-EOF
[Unit]
Description=V2Ray Service
After=network.target nss-lookup.target
[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStartPre=/bin/mkdir -p /tmp/v2ray-ds
ExecStartPre=/bin/rm -rf /tmp/v2ray-ds/*.sock
ExecStart=/usr/local/bin/v2ray -confdir /usr/local/etc/v2ray/
ExecStartPost=/bin/sleep 1
ExecStartPost=/bin/chmod 777 /tmp/v2ray-ds/v2ray.sock
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
}

set_bbr() {
    echo -e "[${green}Info${plain}] 设置bbr..."
    sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
    sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
    ( echo "net.core.default_qdisc = fq"
    echo "net.ipv4.tcp_congestion_control = bbr" ) >> '/etc/sysctl.conf'
    sysctl -p >/dev/null 2>&1
}

install_v2ray(){
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    pre_install
    if [ "$v2" -eq 0 ] ;then
    install_file
    config_v2ray
    systemctl enable v2ray --now
    systemctl enable tls-shunt-proxy --now
    else
    update_v2ray
    update_tsp
    fi
    rm -rf "$TMP_DIR"
}

install_file(){
    echo -e "[${green}Info${plain}] 开始安装${yellow}V2Ray with TCP + TLS + Domain Socket${plain}"
    wget -c "https://api.azzb.workers.dev/$v2link"
    wget -c "https://api.azzb.workers.dev/$tsplink"
    wget -qP /etc/systemd/system/ 'https://cdn.jsdelivr.net/gh/liberal-boy/tls-shunt-proxy@master/dist/tls-shunt-proxy.service'
    unzip -oq "v2ray-linux-64.zip"
    unzip -oq "tls-shunt-proxy-linux-amd64.zip"
    install -m 755 "v2ray" "v2ctl" /usr/local/bin/
    install -m 755 "tls-shunt-proxy" /usr/local/bin/
    if [ -z "$(id tls-shunt-proxy >/dev/null 2>&1)" ] ;then
    useradd tls-shunt-proxy -s /usr/sbin/nologin
    fi
    install -d -o tls-shunt-proxy -g tls-shunt-proxy /etc/ssl/tls-shunt-proxy/
    echo -e "[${green}Info${plain}] V2Ray完成安装！"
}

update_v2ray(){
    echo -e "[${green}Info${plain}] 获取${yellow}v2ray${plain}版本信息..."
    v2latest=$(wget -qO- "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4)
    [ -z "${v2latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
    v2current=v$(/usr/local/bin/v2ray -version | grep V2Ray | cut -d' ' -f2)
    if [ "${v2latest}" == "${v2current}" ]; then
        echo -e "[${green}Info${plain}] ${yellow}V2Ray${plain}已安装最新版本${green}${v2latest}${plain}。"
    else
        echo -e "[${green}Info${plain}] 当前版本：${red}${v2current}${plain}"
        echo -e "[${green}Info${plain}] 最新版本：${red}${v2latest}${plain}"
        echo -e "[${green}Info${plain}] 正在更新${yellow}v2ray${plain}..."
        wget -c "https://api.azzb.workers.dev/$v2link"
        unzip -oq "v2ray-linux-64.zip"
        install -m 755 "v2ray" "v2ctl" /usr/local/bin/
        systemctl restart v2ray
        echo -e "[${green}Info${plain}] ${yellow}v2ray${plain}更新成功！"
    fi
}

update_tsp(){
    echo -e "[${green}Info${plain}] 获取${yellow}tls-shunt-proxy${plain}版本信息..."
    tsplatest=$(wget -qO- "https://api.github.com/repos/liberal-boy/tls-shunt-proxy/releases/latest" | grep 'tag_name' | cut -d\" -f4)
    [ -z "${tsplatest}" ] && [ -z "${v2latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
    tspcurrent=$(/usr/local/bin/tls-shunt-proxy 2>&1| grep version | cut -d' ' -f3)
    if [ "${tsplatest}" == "${tspcurrent}" ]; then
        echo -e "[${green}Info${plain}] ${yellow}tls-shunt-proxy${plain}已安装最新版本${green}${tsplatest}${plain}。"
    else
        echo -e "[${green}Info${plain}] 当前版本：${red}${tspcurrent}${plain}"
        echo -e "[${green}Info${plain}] 最新版本：${red}${tsplatest}${plain}"
        echo -e "[${green}Info${plain}] 正在更新${yellow}tls-shunt-proxy${plain}..."
        wget -c "https://api.azzb.workers.dev/$tsplink"
        unzip -oq "tls-shunt-proxy-linux-amd64.zip"
        install -m 755 "tls-shunt-proxy" /usr/local/bin/
        systemctl restart tls-shunt-proxy
        echo -e "[${green}Info${plain}] ${yellow}tls-shunt-proxy${plain}更新成功！"
    fi
}

info_v2ray(){
    status=$(pgrep -a v2ray|grep -c v2ray)
    tspstatus=$(pgrep -a tls-shunt-proxy|grep -c tls-shunt-proxy)
    [ ! -f /usr/local/etc/v2ray/config.json ] && echo -e "[${red}Error${plain}] 未找到V2Ray配置文件！" && exit 1
    [ ! -f /etc/tls-shunt-proxy/config.yaml ] && echo -e "[${red}Error${plain}] 未找到tls-shunt-proxy配置文件！" && exit 1
    [ "$status" -eq 0 ] && v2status="${red}已停止${plain}" || v2status="${green}正在运行${plain}"
    [ "$tspstatus" -eq 0 ] && tspshuntproxy="${red}已停止${plain}" || tspshuntproxy="${green}正在运行${plain}"
    echo -e " id： ${green}$(< '/usr/local/etc/v2ray/config.json' grep id | cut -d'"' -f4)${plain}"
    echo -e " v2ray运行状态：${v2status}"
    echo -e " tls-shunt-proxy运行状态：${tspshuntproxy}"
}

uninstall_v2ray(){
    echo -e "[${green}Info${plain}] 正在卸载${yellow}v2ray${plain}和${yellow}tls-shunt-proxy${plain}..."
    systemctl disable v2ray --now >/dev/null 2>&1
    systemctl disable tls-shunt-proxy --now >/dev/null 2>&1
    rm -f /usr/local/bin/v2ray
    rm -f /usr/local/bin/v2ctl
    rm -rf /usr/local/etc/v2ray/
    rm -f /etc/systemd/system/v2ray.service
    rm -f /etc/systemd/system/tls-shunt-proxy.service
    rm -f /usr/local/bin/tls-shunt-proxy
    rm -rf /etc/tls-shunt-proxy/
    rm -rf /tmp/v2ray-ds/
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
