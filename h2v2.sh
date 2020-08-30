#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
TMP_DIR="$(mktemp -du)"
uuid=$(cat /proc/sys/kernel/random/uuid)
v2link=https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

check_v2(){
if command -v "v2ray" > /dev/null 2>&1 ;then
        update_v2ray
    fi
}

pre_install(){
    if ! command -v "unzip" > /dev/null 2>&1 ;then
        echo -e "[${green}Info${plain}] 正在安装unzip..."
        if command -v "apt" > /dev/null 2>&1 ;then
            apt -y install unzip
        else
            yum -y install unzip
        fi
    fi
}

config_v2ray(){
    wget -c "https://cdn.jsdelivr.net/gh/771073216/azzb@master/html.zip"
    unzip -oq "html.zip" -d '/var/www'
    echo -e -n "[${green}Info${plain}] 输入域名： "
    read -r domain
    echo -e -n "[${green}Info${plain}] 输入path： "
    read -r h2path
    install -d /usr/local/etc/v2ray/
    set_v2
    set_caddy
    set_bbr
}

set_v2(){
    cat > /usr/local/etc/v2ray/config.json<<-EOF
{
    "inbounds": [
        {
            "protocol": "vmess",
            "listen": "127.0.0.1",
            "port": 2001,
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}"
                    }
                ]
            },
            "streamSettings": {
        "security": "none",
        "network": "h2",
        "httpSettings": {
          "path": "/${h2path}",
          "host": [
            "${domain}"
          ]
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

set_caddy(){
    cat > /etc/caddy/caddyfile<<-EOF
${domain} {
    root * /var/www
    file_server
    reverse_proxy /${h2path} 127.0.0.1:2001 {
        transport http {
            versions h2c
        }
    }
}
EOF
}

set_bbr() {
    echo -e "[${green}Info${plain}] 设置bbr..."
    sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
    sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
    (echo "net.core.default_qdisc = fq" && echo "net.ipv4.tcp_congestion_control = bbr") >> '/etc/sysctl.conf'
    sysctl -p >/dev/null 2>&1
}

update_v2ray(){
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    v2latest=$(wget -qO- "https://api.github.com/repos/v2fly/v2ray-core/releases/latest" | grep 'tag_name' | cut -d\" -f4)
    v2current=v$(/usr/local/bin/v2ray -version | grep V2Ray | cut -d' ' -f2)
    if [ "${v2latest}" == "${v2current}" ]; then
        echo -e "[${green}Info${plain}] ${yellow}V2Ray${plain}已安装最新版本${green}${v2latest}${plain}。"
    else
        echo -e "[${green}Info${plain}] 正在更新${yellow}V2Ray${plain}：${red}${v2current}${plain} --> ${green}${v2latest}${plain}"
        wget -c "https://api.azzb.workers.dev/$v2link"
        unzip -q "v2ray-linux-64.zip"
        install -m 755 "v2ray" "v2ctl" /usr/local/bin/
        systemctl restart v2ray
        echo -e "[${green}Info${plain}] ${yellow}V2Ray${plain}更新成功！"
    fi
    rm -rf "$TMP_DIR"
    exit 0
}

install_v2ray(){
    pre_install
    check_v2
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    wget -c "https://api.azzb.workers.dev/$v2link"
    unzip -jq "v2ray-linux-64.zip"
    install -m 755 "v2ray" "v2ctl" /usr/local/bin/
    install -m 644 "v2ray.service" /etc/systemd/system/
    if ! command -v "caddy" > /dev/null 2>&1 ;then
    echo "deb [trusted=yes] https://apt.fury.io/caddy/ /" > /etc/apt/sources.list.d/caddy-fury.list
    apt update && apt install caddy
    fi
    config_v2
    rm -rf "$TMP_DIR"
    systemctl restart caddy
    systemctl enable v2ray --now
    info_v2ray
}

uninstall_v2ray(){
    echo -e "[${green}Info${plain}] 正在卸载${yellow}v2ray${plain}..."
    systemctl disable v2ray --now
    rm -f /usr/local/bin/v2ray
    rm -f /usr/local/bin/v2ctl
    rm -rf /usr/local/etc/v2ray/
    rm -f /etc/systemd/system/v2ray.service
    echo -e "[${green}Info${plain}] 卸载成功！"
}

info_v2ray(){
    status=$(pgrep -a v2ray|grep -c v2ray)
    [ ! -f /usr/local/etc/v2ray/config.json ] && echo -e "[${red}Error${plain}] 未找到V2Ray配置文件！" && exit 1
    [ "$status" -eq 0 ] && v2status="${red}已停止${plain}" || v2status="${green}正在运行${plain}"
    echo -e " id： ${green}$(< '/usr/local/etc/v2ray/config.json' grep id | cut -d'"' -f4)${plain}"
    echo -e " v2ray运行状态：${v2status}"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
    install|uninstall|info)
    ${action}_v2ray
    ;;
    *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall|info]"
    ;;
esac
