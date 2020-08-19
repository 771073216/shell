#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
TMP_DIR="$(mktemp -du)"

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请以root身份执行该脚本！" && exit 1

check_ss(){
    echo -e "[${green}Info${plain}] 开始安装${yellow} Shadowsocks-rust${plain}"
    latest=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z "${latest}" ] && echo -e "[${red}Error${plain}] 获取失败！" && exit 1
    link=https://github.com/shadowsocks/shadowsocks-rust/releases/download/$latest/shadowsocks-$latest.x86_64-unknown-linux-gnu.tar.xz
    if command -v "ssserver" > /dev/null 2>&1 ;then
        get_update
    fi
}

config_ss(){
    install -d /etc/shadowsocks-rust/
    echo -e -n "[${green}Info${plain}] 输入端口："
    read -r port
    echo -e -n "[${green}Info${plain}] 输入密码："
    read -r passwd
    cat > /etc/shadowsocks-rust/config.json<<-EOF
{
    "server":"::",
    "server_port":$port,
    "password":"$passwd",
    "timeout":300,
    "method":"aes-128-gcm",
    "mode":"tcp_and_udp"
}
EOF
}

install_ss(){
    check_ss
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    config_ss
    wget -cO ss.tar.xz https://api.azzb.workers.dev/"$link"
    wget -cq https://cdn.jsdelivr.net/gh/771073216/azzb@master/shadowsocks.service
    install -m 644 "shadowsocks.service" /etc/systemd/system/
    tar --no-same-owner -xf ss.tar.xz -C /usr/local/bin/
    systemctl enable shadowsocks --now
    rm -rf "$TMP_DIR"
    config_bbr
    echo -e "[${green}Info${plain}] 完成安装！"
}

get_update(){
    mkdir "$TMP_DIR"
    cd "$TMP_DIR" || exit 1
    current=v$(ssserver -V | cut -d" " -f2)
    if [ "${latest}" == "${current}" ]; then
        echo -e "[${green}Info${plain}] 已安装最新版本${green}${latest}${plain}"
    else
        echo -e "[${green}Info${plain}] 当前版本：${red}${current}${plain}"
        echo -e "[${green}Info${plain}] 最新版本：${red}${latest}${plain}"
        echo -e "[${green}Info${plain}] 正在更新${yellow}Shadowsocks-rust${plain}..."
        wget -cO ss.tar.xz https://api.azzb.workers.dev/"$link"
        tar --no-same-owner -xf ss.tar.xz -C /usr/local/bin/
        systemctl restart shadowsocks
    fi
    rm -rf "$TMP_DIR"
    exit 0
}

config_bbr() {
    echo -e "[${green}Info${plain}] 设置bbr..."
    sed -i '/net.core.default_qdisc/d' '/etc/sysctl.conf'
    sed -i '/net.ipv4.tcp_congestion_control/d' '/etc/sysctl.conf'
    ( echo "net.core.default_qdisc = fq"
    echo "net.ipv4.tcp_congestion_control = bbr" ) >> '/etc/sysctl.conf'
    sysctl -p >/dev/null 2>&1
}

uninstall_ss(){
    echo -e "[${green}Info${plain}] 正在卸载${yellow} Shadowsocks-rust${plain}..."
    systemctl disable shadowsocks --now
    rm -f /usr/local/bin/sslocal
    rm -f /usr/local/bin/ssmanager
    rm -f /usr/local/bin/ssserver
    rm -f /usr/local/bin/ssurl
    rm -f /etc/systemd/system/shadowsocks.service
    rm -rf /etc/shadowsocks-rust/
    echo -e "[${green}Info${plain}] 卸载成功！"
}

action=$1
[ -z "$1" ] && action=install
case "$action" in
    install|uninstall|config)
    ${action}_ss
    ;;
    *)
    echo "参数错误！ [${action}]"
    echo "使用方法：$(basename "$0") [install|uninstall|config]"
    ;;
esac
