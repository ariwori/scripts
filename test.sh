#!/bin/bash
if ! ps -ef | grep -v "grep" | grep ss-local > /dev/null 2>&1;
then
    systemctl restart shadowsocks
    echo dddd
fi