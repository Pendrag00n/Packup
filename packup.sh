#!/bin/bash

#
# PACKUP
# LIGHTWEIGHT BACKUP TOOL
# https://github.com/Pendrag00n/Packup
#

#//////////////////////////////
#	CONFIGURATION
#    (Modify accordingly)

backuppath="/var/packup" # Path where the backup will be stored. You can use a remote path by using the format //ip/share
remotebackuppath="false" # Set to true only if you are backing up to a remote path
mountpath="/home/$SUDO_USER/packuptmp" # This variable is only used if remotebackuppath is set to true
logpath="/home/$SUDO_USER" # Path to the log file
files="/etc/ /home/$SUDO_USER/Documents/" # Enter files/folders separated by a space

#///////////////////////////////

# Variables used for formatting the time and date
dirname=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

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

# Check if the files exist
for file in $files; do
    if ! test -e "$file"; then
        echo "ERROR: $file can't be located. Exiting script" >> $logpath/backups.log
        echo "ERROR: $file can't be located. Exiting script"
        exit 2
    fi
done

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
            chmod 600 $mountpath
        fi
        # Check if the backup path is already mounted
        if mount | grep -q "$backuppath .*$mountpath"; then
            echo "Drive seems to be mounted to the mountpath already!"
        else
            # Mount the network drive location into the mountpath
            echo "Mounting remote path..."
            mount -t cifs $backuppath $mountpath -o credentials=$PWD/ales.txt
            if ! mount -t cifs $backuppath $mountpath -o credentials=$PWD/ales.txt;
            sleep 1 #Should work without this line
            then
                echo "The remote path could not be mounted :( Exiting script"
                echo "[ $logdate ]: The remote path could not be mounted :( Exiting script" >> $logpath/backups.log
                exit 2
            fi
            sleep 1 #Should work without this line
        fi
    else
        echo "The credentials file (ales.txt) was not found, place it alongside this script :( Exiting script"
        echo "[ $logdate ]: The credentials file (ales.txt) was not found, place it alongside this script :( Exiting script" >> $logpath/backups.log
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
# DANGEROUS! UNCOMMENT WITH CAUTION AND AT YOUR OWN RISK (I take no responsibility for any data loss)
# find $backuppath -type f -mtime +90 -exec rm -f {} \;
exit 0
