#!/bin/bash
# aria2 start and stop
if [ $1 == "start" ]; then
	eval $(ps -ef | grep "[0-9] aria2" | awk '{print "kill "$2}')
	nohup aria2c --enable-rpc=true --rpc-listen-all=true --input-file=/home/ariwori/.aria2/aria2.session --conf-path=/home/ariwori/Docfiles/aria2.conf >> /dev/null 2>&1 &
fi
if [ $1 == "stop" ]; then
	eval $(ps -ef | grep "[0-9] aria2" | awk '{print "kill "$2}')
fi
