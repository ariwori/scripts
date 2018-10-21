#!/bin/bash
# Run with ROOT
# 每周一份完整备份，每小时一次增量备份
if [ ! -d /backup/filelist ]; then mkdir /backup/filelist; fi
if [ ! -d /backup/rsyncdata ]; then mkdir /backup/rsyncdata; fi
if [ ! -d /backup/tarpkg ]; then mkdir /backup/tarpkg; fi

src_dir="/"
dest_dir="/backup/rsyncdata"
rsync --archive --one-file-system --inplace --hard-links \
  --human-readable --numeric-ids --delete --delete-excluded \
  --acls --xattrs --sparse \
  --itemize-changes --verbose --progress \
  --exclude='*~' --exclude=__pycache__ \
  --exclude-from="/home/ariwori/Ariwori/root.exclude" \
  $src_dir $dest_dir

# tar pkg per day and per hour
week=$(date "+%W")
if [ ! -d /backup/tarpkg/$week ]; then
    mkdir -p /backup/tarpkg/$week
    echo $(date "+%F %T") > /backup/tarpkg/$week/date.txt
    tar -zvcf /backup/tarpkg/$week/sysbackup_$week.tar.gz /backup/rsyncdata
    for w in $(ls /backup/tarpkg); do
        oldweek=`date -d "$(cat /backup/tarpkg/$w/date.txt)" +%W`
        if [ $oldweek -lt $week ]; then
            sudo rm -rf /backup/tarpkg/$w
        fi
    done
else
    day=`date +%F`
    if [ ! -d /backup/tarpkg/$week/$day ]; then
        mkdir -p /backup/tarpkg/$week/$day
    fi
    DATE=`date +%T`
    find $dest_dir -mmin -90 -type f >> /backup/filelist/listfile_${week}_${day}_$DATE
    tar -zvcf /backup/tarpkg/$week/$day/sysbackup_$DATE.tar.gz -T /backup/filelist/listfile_${week}_${day}_$DATE
fi
# shutdown system
if [[ $1 == "off" ]]; then shutdown now; fi 