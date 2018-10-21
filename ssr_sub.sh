#!/usr/bin/env bash
# 基于逗比的ssr脚本生成SSR订阅链接
# 自定SSR订阅链接变量
# 服务端
# 网站SSR订阅链接文件，必填
SSR_site_path="/www/wwwroot/wqlin/ssrlink.html"
# Serverstatus 服务端数据文件
ss_json_file='/www/wwwroot/wqlin/status/json/stats.json'

# 客户端
# SSR群组名称，必填
SSRGroup="wqlin.com"
# 当前SSR名称，必填
SSRRemarks="搬瓦工[洛杉矶机房]"
# 逗比脚本变量
ssr_folder="/usr/local/shadowsocksr"
config_folder="/etc/shadowsocksr"
config_user_file="${config_folder}/user-config.json"
jq_file="${ssr_folder}/jq"
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Get_User(){
	port=`${jq_file} '.server_port' ${config_user_file}`
	password=`${jq_file} '.password' ${config_user_file} | sed 's/^.//;s/.$//'`
	method=`${jq_file} '.method' ${config_user_file} | sed 's/^.//;s/.$//'`
	protocol=`${jq_file} '.protocol' ${config_user_file} | sed 's/^.//;s/.$//'`
	obfs=`${jq_file} '.obfs' ${config_user_file} | sed 's/^.//;s/.$//'`
}
urlsafe_base64(){
	date=$(echo -n "$1"|base64|sed ':a;N;s/\n/ /g;ta'|sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
	echo -e "${date}"
}
ssr_link_qr(){
	SSRprotocol=$(echo ${protocol} | sed 's/_compatible//g')
	SSRobfs=$(echo ${obfs} | sed 's/_compatible//g')
	SSRPWDbase64=$(urlsafe_base64 "${password}")
	SSRMainSTR="${ip}:${port}:${SSRprotocol}:${method}:${SSRobfs}:${SSRPWDbase64}"
	if [ ! -f /tmp/ssrstring.txt ]; then
		echo $SSRMainSTR > /tmp/ssrstring.txt
		Update_SSR_link
	else
		OLD_SSRMainSTR=$(cat /tmp/ssrstring.txt)
		if [[ $SSRMainSTR != $OLD_SSRMainSTR ]]; then
			Update_SSR_link
		fi
	fi
}
Update_SSR_link(){
	SSRGroupbase64=$(urlsafe_base64 "${SSRGroup}")
	datestr=$(date +%s)
	marks="${SSRRemarks}($datestr)"
	marksbase64=$(urlsafe_base64 "${marks}")
	SSRbase64=$(urlsafe_base64 "${SSRMainSTR}/?obfsparam=&protoparam=&remarks=${marksbase64}&group=${SSRGroupbase64}")
	echo "$SSRbase64" > /tmp/ssrlink.txt
}
if [[ $1 == 'c' ]]; then
	while (true); do
		Get_IP
		Get_User
		ssr_link_qr
		sleep 60
	done
fi
if [[ $1 == 's' ]]; then
	while (true); do
		rm /tmp/ssralllink.txt
		touch /tmp/ssralllink.txt
		if [ -f $ss_json_file ]; then
			num=$[$(cat $ss_json_file | ${jq_file} '.servers' | ${jq_file} 'length') - 1]
			for i in $(seq 1 $num); do
				ssrallstr=$(cat $ss_json_file | ${jq_file} ".servers[$i].custom" | cut -d '"' -f2)
				echo "ssr://$ssrallstr" >> /tmp/ssralllink.txt
			done
			allstr=$(cat /tmp/ssralllink.txt)
			echo $(urlsafe_base64 $allstr) > $SSR_site_path
			sleep 60
		fi
	done
fi