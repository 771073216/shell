#!/usr/bin/env bash

init() {
  sudo apt update -y
  sudo apt full-upgrade -y
  sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
    git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz \
    mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pyelftools \
    libpython3-dev qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
    vim wget xmlto xxd zlib1g-dev
  git clone https://github.com/coolsnowwolf/lede.git lede/
  pushd lede/ || exit
  add_feeds
  ./scripts/feeds update -a && ./scripts/feeds install -a
  modify
  popd || exit
  chmod +x "$0"
  cp "$0" lede/
}

easy() {
  sudo apt update -y
  sudo apt full-upgrade -y
  sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
    git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz \
    mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pyelftools \
    libpython3-dev qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
    vim wget xmlto xxd zlib1g-dev
  git clone https://github.com/coolsnowwolf/lede.git lede/ --depth=1
  pushd lede/ || exit
  add_feeds
  ./scripts/feeds update -a && ./scripts/feeds install -a
  modify
  popd || exit
  chmod +x "$0"
  cp "$0" lede/
}

add_feeds() {
  {
    echo "src-git passwall https://github.com/xiaorouji/openwrt-passwall.git"
    echo "src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git"
  } >> feeds.conf
}

restore() {
  git restore include/target.mk
  git restore target/linux/x86/Makefile
}

modify() {
  include="ddns-scripts_aliyun ddns-scripts_dnspod luci-app-ddns \
	luci-app-arpbind luci-app-ssr-plus luci-app-vlmcsd \
	luci-app-accesscontrol luci-app-nlbwmon luci-app-turboacc luci-app-wol"
  for a in $include; do
    sed -i "s/$a//g" include/target.mk
  done
  sed -i '/^[[:space:]]*\\/d' include/target.mk
  sed -i 's|\t[[:space:]]\{2,\}|\t|g' include/target.mk

  mkfile="autosamba luci-app-adbyby-plus luci-app-ipsec-vpnd luci-proto-bonding \
	luci-app-unblockmusic luci-app-zerotier luci-app-xlnetacc ddns-scripts_aliyun \
	ddns-scripts_dnspod ca-bundle luci-app-wireguard luci-app-ttyd"
  for b in $mkfile; do
    sed -i "s/$b//g" target/linux/x86/Makefile
  done
  sed -i '/^[[:space:]]*\\/d' target/linux/x86/Makefile
  sed -i 's|[[:space:]]\{2,\}| |g' target/linux/x86/Makefile
}

update() {
  restore
  git pull
  ./scripts/feeds update -a && ./scripts/feeds install -a
  modify
}

repair() {
  ./scripts/feeds uninstall -a
  rm -rf feeds/ tmp/
  update
}

clean() {
  i=0
  list=$(find build_dir/target-* -maxdepth 1 -name 'root-*' | awk -F'root-' '{print$2}')
  for select in $list; do
    i=$((i + 1))
    a[$i]=$select
    echo "[$i] $select"
  done
  echo "[a] clean all"
  echo -n "clean which: "
  read -r m
  if [ "$m" != "a" ]; then
    name=$(find build_dir/target-*/root-"${a[$m]}"/etc -name os-release -exec awk -F'"' '/OPENWRT_ARCH/{print$2}' {} \;)
    rm -rf build_dir/target-"${name}"* build_dir/toolchain-"${name}"*
    rm -rf staging_dir/target-"${name}"* staging_dir/toolchain-"${name}"*
  else
    rm -rf build_dir/ dl/ tmp/ staging_dir/
    ./scripts/feeds install -a
  fi
}

action=$1
[ -z "$1" ] && action=-u
case "$action" in
  -u)
    update
    ;;
  -r | repair)
    repair
    ;;
  -c | clean)
    clean
    ;;
  -i | init)
    init
    ;;
  -e | easy)
    easy
    ;;
  *)
    echo "参数错误！ [${action}]"
    ;;
esac
