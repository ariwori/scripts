# 利用genpac更新代理规则脚本
#！/bin/bash
nohup genpac --proxy="SOCKS5 127.0.0.1:1080" -o /home/ariwori/Ariwori/autoproxy.pac --gfwlist-url="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt" --user-rule-from="/home/ariwori/Ariwori/user-rule.txt" >> /dev/null 2>&1 &
