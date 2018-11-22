# 利用genpac更新代理规则脚本
#！/bin/bash
genpac --proxy="SOCKS5 127.0.0.1:1080" -o /home/ariwori/Docfiles/autoproxy.pac --gfwlist-url="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt" --user-rule-from="/home/ariwori/Docfiles/user-rule.txt"
