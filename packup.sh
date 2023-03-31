#!/bin/bash

#
# PACKUP
# LIGHTWEIGHT BACKUP TOOL
# https://github.com/Pendrag00n/Packup
#

#//////////////////////////////
#	CONFIGURATION
#    (Modify accordingly)

backuppath="//192.168.117.104/RECURSOCOMPARTIDO" # Path where the backup will be stored. You can use a remote path by using the format //ip/share
remotebackuppath="true" # Set to true only if you are backing up to a remote path
mountpath="/home/julio/packuptmp" # This variable is only used if remotebackuppath is set to true
logpath="/home/julio" # Path to the log file
files="/etc/" # Enter files/folders separated by a space
#compressionlvl="4" # NOT WORKING FOR SOME REASON. Where 1 is no compression and 9 is maximum compression (6 is default)

#///////////////////////////////

# If $backuppath ends with a /, remove it.
if [ ${backuppath: -1} = "/" ]; then
    backuppath=${backuppath::-1}
fi
# If $mountpath ends with a /, remove it
if [ ${mountpath: -1} = "/" ]; then
    mountpath=${mountpath::-1}
fi
# If $logpath ends with a /, remove it
if [ ${logpath: -1} = "/" ]; then
    logpath=${logpath::-1}
fi

for file in $files; do
    if ! test -e "$file"; then
        echo "ERROR: $file can't be located. Exiting script" >> $logpath/backups.log
        echo "ERROR: $file can't be located. Exiting script"
    fi
    exit 2
done

dirname=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

# Start script
if ! which tar >/dev/null; then
    apt install tar -y
    echo "tar was surprisingly not installed and is being installed now"
    echo "[ $logdate ]: tar was surprisingly not installed and was automatically installed" >> $logpath/backups.log
fi



# Test credentials file (ales.txt) and mount backup path
if [ $remotebackuppath = "true" ]; then
    if [ -f ales.txt ]; then
        chown root:root ales.txt
        chmod 600 ales.txt
        if [ ! -d $mountpath ]; then
            mkdir -p $mountpath
            chown root:root $mountpath
            chmod 600 $mountpath #IF NOT WORKING, SWITCH TO 777...
        fi
        mount -t cifs $backuppath $mountpath -o credentials=$PWD/ales.txt #CHANGE CREDS LOCATION TO VARIABLE
        sleep 1 #Should work without this line
    else
        echo "The credentials file (ales.txt) was not found :( Exiting script"
        echo "[ $logdate ]: The credentials file (ales.txt) was not found :( Exiting script" >> $logpath/backups.log
        exit 2
    fi
    
    
    if ! mount -t cifs $backuppath $mountpath -o credentials=$PWD/ales.txt;
    then
        echo "The remote path could not be mounted :( Exiting script"
        echo "[ $logdate ]: The remote path could not be mounted :( Exiting script" >> $logpath/backups.log
        exit 2
    fi
fi

if [ ! -d $backuppath ]; then
    mkdir -p $backuppath
fi

if [ $remotebackuppath = "true" ]; then
    tar -cf $mountpath/packup_$dirname.tar.gz $files &> $logpath/temp_backups_error.log
    backuppath=$mountpath
else
    tar -cf $backuppath/packup_$dirname.tar.gz $files &> $logpath/temp_backups_error.log
fi

if [ $? -eq 0 ]; then
    echo "packup_$dirname.tar.gz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh $backuppath/packup_$dirname.tar.gz | awk '{print $1}') )"
    echo "[ $logdate ]: packup_$dirname.tar.gz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh $backuppath/packup_$dirname.tar.gz | awk '{print $1}'))" >> $logpath/backups.log
    chmod 600 $backuppath/packup_$dirname.tar.gz
else
    echo "Backup exited with errors and the zipfile was deleted :("
    echo "[ $logdate ]: Backup exited with errors and the tarfile was deleted :(" >> $logpath/backups.log
    
    if [ -f $backuppath/packup_$dirname.tar.gz ]; then
        rm -rf $backuppath/packup_$dirname.tar.gz
    fi
    
    if [ -s $logpath/temp_backups_error.log ]; then
        echo "Encountered the following errors:" >> $logpath/backups.log
        cat $logpath/temp_backups_error.log >> $logpath/backups.log
        echo "" >> $logpath/backups.log
    fi
    
    if [ -f $logpath/temp_backups_error.log ]; then
        rm -f $logpath/temp_backups_error.log
    fi
    
fi

if [ $remotebackuppath = "true" ]; then
    umount $mountpath
fi
# Check for backups older than 3 months inside $backuppath and delete them
# find $backuppath -type f -mtime +90 -exec rm -f {} \;
exit
