#!/bin/bash
# 简单的用于在搬瓦工CentOS7+BBR系统上一键安装SS C语言版本服务端（Shadowsocks-libev）的脚本，搬瓦工的建议选择带bbr的系统，脚本默认开启tcp_fast_open
# SSR已年久失修，而Shadowsocks-libev（https://github.com/shadowsocks/shadowsocks-libev）还一直有人维护，建议换用SS
# Run on ROOT

# 使用方法，连接服务器终端执行以下命令即可，别带#号
# curl -s https://wqlin.com/files/dst/ss.sh > s.sh  && chmod +x ss.sh && bash installss.sh

script_cfg_dir="$HOME/.ss"
ss_cfg_file="/etc/shadowsocks.json"

Init_script(){
    if [ ! -d $script_cfg_dir ]
    then
        mkdir -p $script_cfg_dir
    fi
     if [ ! -f $script_cfg_dir/ss.conf ]
    then
        touch $script_cfg_dir/ss.conf
    fi
}
Get_cfg(){
    unset result
    if [ $(grep $1 -c "$script_cfg_dir/ss.conf") -gt 0 ]
    then
        result=$(grep "^${1}" "$script_cfg_dir/ss.conf" | cut -d "=" -f2)
    fi
}
Change_cfg(){
    if [ $(grep "^$1=" -c "$script_cfg_dir/ss.conf") -gt 0 ]
    then
        linen=$(grep "^$1=" -n "$script_cfg_dir/ss.conf" | cut -d ":" -f1)
        sed -i ${linen}d "$script_cfg_dir/ss.conf"
        echo "$1=$2" >> "$script_cfg_dir/ss.conf"
    else
        echo "$1=$2" >> "$script_cfg_dir/ss.conf"
    fi
}
Install_ss(){
    info "正在安装/更新系统及所需依赖 ..."
    yum update -y
    yum install epel-release -y
    yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel git vim wget -y
    info "系统及所需依赖安装更新完毕！"
    # Installation of Libsodium
    # 下在最新版本的Libsodium
    Get_cfg "Libsodium_ver"
    cur_libso_ver=$result
    new_libso_ver=$(curl -s https://download.libsodium.org/libsodium/releases/ | grep ">libsodium-.*.tar.gz</a>" | tail -n 2 | head -n 1 | cut -d '>' -f2 | cut -d '<' -f1 | cut -d '-' -f2 )
    if [[ $cur_libso_ver == "" || $cur_libso_ver != $new_libso_ver ]]
    then
        info "正在安装/更新Libsodium(V $new_libso_ver) ..."
        Libsodium_ver=$new_libso_ver
        wget https://download.libsodium.org/libsodium/releases/libsodium-${Libsodium_ver}-stable.tar.gz
        tar xvf libsodium-${Libsodium_ver}-stable.tar.gz
        pushd libsodium-stable
        ./configure --prefix=/usr
        make && make install
        popd && ldconfig
        Change_cfg "Libsodium_ver" $new_libso_ver
        info "安装/更新Libsodium(V $new_libso_ver)完毕！"
    else
        info "Libsodium(V $new_libso_ver)无更新！"
    fi
    # Installation of MbedTLS
    Get_cfg "MBEDTLS_VER"
    cur_mbedtls_ver=$result
    new_mbedtls_ver=$(curl -s https://tls.mbed.org/download | grep -A 1 "Latest stable release for mbed TLS" | cut -d '>' -f3 | grep strong | cut -d '<' -f1)
    if [[ $cur_mbedtls_ver == "" || $cur_mbedtls_ver != $new_mbedtls_ver ]]
    then
        MBEDTLS_VER=$new_mbedtls_ver
        info "正在安装/更新MBEDTLS(V $new_mbedtls_ver) ..."
        wget https://tls.mbed.org/download/mbedtls-${MBEDTLS_VER}-gpl.tgz
        tar xvf mbedtls-${MBEDTLS_VER}-gpl.tgz
        pushd mbedtls-$MBEDTLS_VER
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        popd && ldconfig
        Change_cfg "MBEDTLS_VER" $new_mbedtls_ver
        info "安装/更新MBEDTLS(V $new_mbedtls_ver)完毕！"
    else
        info "MBEDTLS(V $new_mbedtls_ver)无更新！"
    fi
    # 拉去SS-libev源码编译安装
    new_ss_ver=$(curl -s "https://github.com/shadowsocks/shadowsocks-libev/tags" | grep '<a href="/shadowsocks/shadowsocks-libev/releases/tag/' | head -n 1 | cut -d 'v' -f3 | cut -d '"' -f1) > /dev/null 2>&1
    cur_ss_ver=$(ss-server -h | grep "shadowsocks-libev" | cut -d ' ' -f2) > /dev/null 2>&1
    #https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${ss_new_ver}/shadowsocks-libev-${ss_new_ver}.tar.gz
    if [[ $cur_ss_ver == "" || $cur_ss_ver != $new_ss_ver ]]
    then
        info "正在安装/更新SS(V $new_ss_ver) ..."
        git clone https://github.com/shadowsocks/shadowsocks-libev.git
        cd shadowsocks-libev
        git submodule update --init --recursive
        # Start building
        ./autogen.sh && ./configure
        make && make install
        cd
        info "安装/更新SS(V $new_ss_ver)完毕！"
    else
        info "SS(V $new_ss_ver)无更新！"
    fi
    Get_cfg "Init_done"
    init_done=$result
    if [[ $init_done == "" ]]
    then
        info "正在初始化SS配置 ..."
        # TCP fast open
        if [ $(grep "tcp_fastopen" -c /etc/sysctl.conf) -eq 0 ]
        then
            echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.conf
            sysctl -p
        fi
        if [ ! -f /etc/systemd/system/shadowsocks.service ]
        then
        # Boot service
            cat > /etc/systemd/system/shadowsocks.service<<-EOF
[Unit]
Description=Shadowsocks
After=network-online.target

[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/ss-server -c ${ss_cfg_file} /dev/null 2>&1

[Install]
WantedBy=multi-user.target
EOF
        fi
        if [ ! -f $ss_cfg_file ]
        then
            # Config
            cat > ${ss_cfg_file}<<-EOF
{
    "server":"0.0.0.0",
    "server_port":8080,
    "password":"123456",
    "timeout":300,
    "user":"nobody",
    "method":"aes-192-gcm",
    "fast_open":true,
    "nameserver":"8.8.8.8",
    "mode":"tcp_and_udp"
}
EOF
            # start
            systemctl enable shadowsocks
        fi
        # 进程守护
        if [ ! -f $script_cfg_dir/keeplive.sh ]
        then
            cat > /root/.ss/keeplive.sh<<-EOF
#!/bin/bash
if ! ps -ef | grep -v "grep" | grep ss-server > /dev/null 2>&1;
then
    systemctl restart shadowsocks
fi
EOF
        fi
        if [ ! -f $script_cfg_dir/crontab ]
        then
            crontab -l > $script_cfg_dir/crontab
            echo '*/10 * * * * bash /root/.ss/keeplive.sh > /dev/null 2>&1' >> $script_cfg_dir/crontab
            crontab $script_cfg_dir/crontab
        fi
        # clean file
        info "正在清理安装文件 ..."
        rm -rf libsodium-stable libsodium-${Libsodium_ver}-stable libsodium-${Libsodium_ver}-stable.tar.gz mbedtls-${MBEDTLS_VER}-gpl.tgz mbedtls-${MBEDTLS_VER} shadowsocks-libev
		Change_cfg "Init_done" "True"
        info "初始化SS配置完成！重启后SS服务即以默认配置运行，可自行修改后重启SS生效！"
        info "===默认配置如下===="
        cat ${ss_cfg_file}
        info "脚本运行命令：./ss.sh !!! 任意键重启服务器（必须），几分钟后可尝试重连！>>>"
        read rb
        reboot
    fi
}
Get_ss_ver(){
    ss_cur_ver=$(ss-server -h | grep "shadowsocks-libev" | cut -d ' ' -f2) > /dev/null 2>&1
    if [[ $ss_cur_ver == "" ]]
    then
        ss_cur_ver_str="未安装！请先安装！"
    else
        ss_cur_ver_str="V $ss_cur_ver"
    fi
}
Get_ss_status(){
    if ! ps -ef | grep -v "grep" | grep ss-server > /dev/null 2>&1;
    then
        ss_status="未运行！"
    else
        ss_status="运行中！"
    fi
}
Diff_file(){
    cmp -s $1 $2
    if [ $? -eq 1 ]
    then
        return 0
    else
        return 1
    fi
}
Update_script(){
    info "正在检查脚本是否有更新 ..."
    wget https://wqlin.com/files/ss/ss.sh -O /tmp/ss.sh -o /tmp/ss.log
    if grep "‘/tmp/ss.sh’ saved" /tmp/ss.log > /dev/null 2>&1
    then
        if Diff_file /tmp/ss.sh $HOME/ss.sh
        then
            mv /tmp/ss.sh $HOME/ss.sh
            chmod +x $HOME/ss.sh
            tip "脚本已更新并退出，请重新运行以使更新生效！"
            exit
        else
            info "脚本没有更新可用！"
        fi
    else
        error "无法连接更新服务，请重试，多次不行请反馈或不更新！"
    fi
}
Run_ss(){
    systemctl start shadowsocks.service
}
Stop_ss(){
    systemctl stop shadowsocks.service
}
Restart_ss(){
    systemctl restart shadowsocks.service
}
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="无法获取，请自行查看商家后台！"
			fi
		fi
	fi
}
Modify_ss_cfg(){
    Get_IP
    while (true)
    do
        sleep 1
        clear
        ss_passwd=$(grep "password" ${ss_cfg_file} | cut -d '"' -f4)
        ss_port=$(grep "server_port" ${ss_cfg_file} | cut -d ':' -f2 | cut -d ',' -f1)
        ss_method=$(grep "method" ${ss_cfg_file} | cut -d '"' -f4)
        echo -e "\e[33m==服务端SS信息[修改后需重启]==========\e[0m"
        echo -e "\e[31m  SS版本：${ss_cur_ver_str}\e[0m"
        echo -e "\e[31m  SS运行状态：$ss_status\e[0m"
        echo -e "\e[31m  服务器IP：$ip\e[0m"
        echo -e "\e[92m     [1] SS密码：${ss_passwd}\e[0m"
        echo -e "\e[92m     [2] SS端口：${ss_port}\e[0m"
        echo -e "\e[92m     [3] SS加密协议：${ss_method}\e[0m"
        echo -e "\e[33m=======================================\e[0m"
        echo -e "\e[92m[保存退出输入数字 0 ]请输入配置对应代号以修改：\e[0m\c"
        read cfg
        case $cfg in
            1)
            info "请设置SS服务连接密码：\c"
            read password
            [ -z $password ] && password="123456"
            sed -i "s/\"password\":\"${ss_passwd}\"/\"password\":\"${password}\"/g" ${ss_cfg_file}
            ;;
            2)
            info "请设置SS服务器连接端口：（如无占用建议常用的443 80 21 8080等端口）\c"
            read port
            [ -z $port ] && port=8080
            sed -i "s/\"server_port\":${ss_port}/\"server_port\":${port}/g" ${ss_cfg_file}
            ;;
            3)
            echo -e "\e[33m=======================================\e[0m"
            echo "[ 1] rc4-md5"
            echo "[ 2] aes-128-gcm  [ 3] aes-192-gcm  [ 4] aes-256-gcm"
            echo "[ 5] aes-128-cfb  [ 6] aes-192-cfb  [ 7] aes-256-cfb"
            echo "[ 8] aes-128-ctr  [ 9] aes-192-ctr  [10]aes-256-ctr"
            echo "[11] camellia-128-cfb  [12] camellia-192-cfb  [13] camellia-256-cfb"
            echo "[14] bf-cfb       [15] chacha20-ietf-poly1305 [16] xchacha20-ietf-poly1305"
            echo "[17] salsa20      [18] chacha20     [19] chacha20-ietf"
            echo -e "\e[33m=======================================\e[0m"
            info "请选择SS服务加密协议：\c"
            read s_method
            case $s_method in
                1)
                methods="rc4-md5"
                ;;
                2)
                method="aes-128-gcm"
                ;;
                3) 
                method="aes-192-gcm"
                ;;
                4)
                method="aes-256-gcm"
                ;;
                5)
                method="aes-128-cfb"
                ;;
                6)
                method="aes-192-cfb"
                ;;
                7)
                method="aes-256-cfb"
                ;;
                8)
                method="aes-128-ctr"
                ;;
                9)
                method="aes-192-ctr"
                ;;
                10)
                mrthod="aes-256-ctr"
                ;;
                11)
                method="camellia-128-cfb"
                ;;
                12)
                method="camellia-192-cfb"
                ;;
                13)
                method="camellia-256-cfb"
                ;;
                14)
                method="bf-cfb"
                ;;
                15)
                method="chacha20-ietf-poly1305"
                ;;
                16)
                method="xchacha20-ietf-poly1305"
                ;;
                17)
                method="salsa20"
                ;;
                18)
                method="chacha20"
                ;;
                19)
                method="chacha20-ietf"
                ;;
                *)
                error "输入有误！"
                ;;
            esac
            [ -z $method ] && method="aes-192-gcm"
            sed -i "s/\"method\":\"${ss_method}\"/\"method\":\"${method}\"/g" ${ss_cfg_file}
            ;;
            0)
            Menu
            ;;
            *)
            error "输入有误！"
            ;;
        esac
    done
}
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[提示]${Font_color_suffix}"
info(){
    echo -e "${Info}" "$1"
}
tip(){
    echo -e "${Tip}" "$1"
}
error(){
    echo -e "${Error}" "$1"
}
# Main menu
Menu(){
    while (true)
    do
        sleep 1
        clear
        Get_ss_ver
        Get_ss_status
        echo -e "\e[33m==Shadowsocks-libev 服务端管理脚本===\e[0m"
        echo -e "\e[31m    SS版本：${ss_cur_ver_str}\e[0m"
        echo -e "\e[31m    SS运行状态：$ss_status\e[0m"
        echo -e "\e[92m      [1] 安装/更新SS\e[0m"
        echo -e "\e[92m      [2] 启动SS\e[0m"
        echo -e "\e[92m      [3] 关闭SS\e[0m"
        echo -e "\e[92m      [4] 重启SS\e[0m"
        echo -e "\e[92m      [5] 查看/修改SS配置信息\e[0m"
        echo -e "\e[92m      [6] 更新脚本\e[0m"
        echo -e "\e[92m      [7] 退出脚本\e[0m"
        echo -e "\e[33m======================================\e[0m"
        echo -e "\e[92m输入命令代号：\e[0m\c"
        read -r cmd
        case "${cmd}" in
            1)
            Install_ss
            ;;
            2)
            Run_ss
            ;;
            3)
            Stop_ss
            ;;
            4)
            Restart_ss
            ;;
            5)
            Modify_ss_cfg
            ;;
            6)
            Update_script
            ;;
            7)
            exit
            ;;
            *)
            error "输入有误！！！"
            ;;
        esac
    done
}
Menu