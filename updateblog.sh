#!/bin/bash

update='false'
wwwroot='/usr/share/nginx'
if [ ! -f /root/.blog/version.txt ]
then
    update="true"
    new_ver=$(cat $wwwroot/api/webhook/result.txt)
else
    cur_ver=$(cat /root/.blog/version.txt)
    new_ver=$(cat $wwwroot/api/webhook/result.txt)
    if [[ $cur_ver != $new_ver ]]
    then
        update="true"
    fi
fi
if [[ ${update} == "true" ]]
then

    if [ ! -d $wwwroot/blog ]
    then
        git clone git@git.dev.tencent.com:ariwori/typechoblog.git $wwwroot/blog
    fi
    cd $wwwroot/blog

    mysqldump typecho > typecho.sql

    git pull
    git add .
    git commit -m "$(date) update from server"
    git push && echo ${new_ver} > /root/.blog/version.txt

    chmod -R 755 $wwwroot/blog
    chown -R nginx:nginx $wwwroot/blog
fi

# * * * * * sleep 5; flock -xn /root/.blog/blog.lock -c 'bash /root/.blog/updateblog.sh'