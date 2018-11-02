#!/bin/bash
# Install Shadowsocks-libev on CentOS7 for Serverq
# Run on ROOT

yum update -y
yum install epel-release -y
yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel git vim wget -y
# Installation of Libsodium
# 下在最新版本的Libsodium
export Libsodium_ver=$(curl -s https://download.libsodium.org/libsodium/releases/ | grep ">libsodium-.*.tar.gz</a>" | tail -n 2 | head -n 1 | cut -d '>' -f2 | cut -d '<' -f1 | cut -d '.' -f1-3)
wget https://download.libsodium.org/libsodium/releases/$Libsodium_ver.tar.gz
tar xvf $Libsodium_ver.tar.gz
pushd $Libsodium_ver
./configure --prefix=/usr
make && make install
popd && ldconfig
# Installation of MbedTLS
export MBEDTLS_VER=$(curl -s https://tls.mbed.org/download | grep -A 1 "Latest stable release for mbed TLS" | cut -d '>' -f3 | grep strong | cut -d '<' -f1)
wget https://tls.mbed.org/download/mbedtls-${MBEDTLS_VER}-gpl.tgz
tar xvf mbedtls-${MBEDTLS_VER}-gpl.tgz
pushd mbedtls-$MBEDTLS_VER
make SHARED=1 CFLAGS=-fPIC
make DESTDIR=/usr install
popd && ldconfig
# 拉去SS-libev源码编译安装
git clone https://github.com/shadowsocks/shadowsocks-libev.git
cd shadowsocks-libev
git submodule update --init --recursive
# Start building
./autogen.sh && ./configure
make && make install
cd
# TCP fast open
echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.conf
sysctl -p
# Boot service
cat > /etc/systemd/system/shadowsocks.service<<-EOF
[Unit]
Description=Shadowsocks
After=network-online.target

[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks.json /dev/null 2>&1

[Install]
WantedBy=multi-user.target
EOF
# Config
cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":8080,
    "password":"lwq@123456",
    "timeout":300,
    "user":"nobody",
    "method":"aes-128-gcm",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
# start
systemctl enable shadowsocks
systemctl start shadowsocks
# 进程守护
mkdir -pv /root/.ss
cat > /root/.ss/keeplive.sh<<-EOF
#!/bin/bash
if ! ps -ef | grep -v "grep" | grep ss-server > /dev/null 2>&1;
then
    systemctl restart shadowsocks
fi
EOF
crontab -l > /root/.ss/crontab
echo '*/10 * * * * bash /root/.ss/keeplive.sh > /dev/null 2>&1' >> /root/.ss/crontab
crontab /root/.ss/crontab
# clean file
rm -rf installss.sh  $Libsodium_ver $Libsodium_ver.tar.gz mbedtls-${MBEDTLS_VER}-gpl.tgz mbedtls-${MBEDTLS_VER} shadowsocks-libev

echo "All Done! Reboot！！！"
sleep 1
reboot 
