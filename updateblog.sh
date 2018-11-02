#!/bin/bash

tmpdir='/tmp'
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
    rm -rf $tmpdir/typechouploads
    mkdir -p $tmpdir/typechouploads
    cp -rf $wwwroot/blog/usr/uploads/* $tmpdir/typechouploads/
    if [ ! -d $tmpdir/typechoblog ]
    then
        git clone git@git.dev.tencent.com:ariwori/typechoblog.git $tmpdir/typechoblog
    else
        cd /tmp/typechoblog && git pull
    fi
    rm -rf $wwwroot/blog
    mkdir -p $wwwroot/blog
    cp -rf $tmpdir/typechoblog/* $wwwroot/blog/
    cp -rf $tmpdir/typechouploads/* $wwwroot/blog/usr/uploads/
    rm -rf $wwwroot/blog/.git
    echo ${new_ver} > /root/.blog/version.txt
fi

# * * * * * sleep 5; flock -xn /root/.blog/blog.lock -c 'bash /root/.blog/updateblog.sh'