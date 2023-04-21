#!/bin/bash

#
# PACKUP
# LIGHTWEIGHT BACKUP TOOL
# https://github.com/Pendrag00n/Packup
# ShellCheck Standards Compliant
#

#//////////////////////////////
#	CONFIGURATION
#    (Modify accordingly)

backuppath="/var/packup" # Path where the backup will be stored. You can use a remote path by using the format //ip/share
logpath="/home/$SUDO_USER" # Path to the log file
logfile="packup.log" # Name of the log file
files="/etc/ /home/$SUDO_USER/Documents/" # Enter files/folders separated by a space
    # Remote backup variables:
    mountpath="/home/$SUDO_USER/packuptmp" # This variable is only used if backup up to a remote location
    mountport="445" # Default SMB/CIFS port
    unmountwhenfinished="true" # If set to true, the remote path will be unmounted when the backup is finished

#///////////////////////////////

# Variables used for formatting the time and date
dirname=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

#If $backuppath starts with // then set $remotebackuppath to true
if [ ${backuppath:0:2} = "//" ]; then
    remotebackuppath="true"
fi

# If $backuppath ends with a /, remove it.
if [ ${backuppath: -1} = "/" ]; then
    backuppath=${backuppath::-1}
fi
# If $mountpath ends with a /, remove it
if [ "${mountpath: -1}" = "/" ]; then
    mountpath=${mountpath::-1}
fi
# If $logpath ends with a /, remove it
if [ "${logpath: -1}" = "/" ]; then
    logpath=${logpath::-1}
fi

# Check if the files exist
for file in $files; do
    if ! test -e "$file"; then
        echo "ERROR: $file can't be located. Exiting script" >> "$logpath"/$logfile
        echo "ERROR: $file can't be located. Exiting script"
        exit 2
    fi
done


# Start script
if ! which tar >/dev/null; then
    apt install tar -y
    echo "tar was surprisingly not installed and is being installed now"
    echo "[ $logdate ]: tar was surprisingly not installed and was automatically installed" >> "$logpath"/$logfile
fi

# Test credentials file (ales.txt) and mount backup path
if [ "$remotebackuppath" = "true" ]; then
    if [ -f ales.txt ]; then
        chown root:root ales.txt
        chmod 600 ales.txt
        #Test if the IP provided has port 445 enabled
            IP=$(echo "$backuppath" | cut -d/ -f3)
            echo "Testing if share is up on port 445..."
            if echo "Q" | nc -w 5 "$IP" $mountport >/dev/null; then
                echo "Share is up on port $mountport !"
            else
                echo "Error: Network share doesn't see to be up on port $mountport :( Exiting script..."
                exit 1
            fi
        
        if [ ! -d "$mountpath" ]; then
            mkdir -p "$mountpath"
        fi
            chown root:root "$mountpath"
            chmod 600 "$mountpath"
        # Check if the backup path is already mounted
        if mount | grep -q "$backuppath .*$mountpath"; then
            echo "Drive seems to be mounted to the mountpath already!"
        else
            # Mount the network drive location into the mountpath
            echo "Mounting remote path..."
            mount -t cifs "$backuppath" "$mountpath" -o credentials="$PWD"/ales.txt
            if ! mount -t cifs "$backuppath" "$mountpath" -o credentials="$PWD"/ales.txt;
            sleep 1 #Should work without this line
            then
                echo "The remote path could not be mounted :( Exiting script"
                echo "[ $logdate ]: The remote path could not be mounted :( Exiting script" >> "$logpath"/$logfile
                exit 2
            fi
            sleep 1 #Should work without this line
        fi
    else
        echo "The credentials file (ales.txt) was not found, place it alongside this script :( Exiting script"
        echo "[ $logdate ]: The credentials file (ales.txt) was not found, place it alongside this script :( Exiting script" >> "$logpath"/$logfile
        exit 2
    fi
fi


if [ ! -d "$backuppath" ]; then
    mkdir -p "$backuppath"
fi

if [ "$remotebackuppath" = "true" ]; then
    tar -cf "$mountpath"/packup_"$dirname".tar.gz "$files" &> "$logpath"/temp_backups_error.log
    backuppath=$mountpath
else
    tar -cf "$backuppath"/packup_"$dirname".tar.gz "$files" &> "$logpath"/temp_backups_error.log
fi

if [ $? -eq 0 ]; then
    echo "packup_$dirname.tar.gz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$dirname".tar.gz | awk '{print $1}') )"
    echo "[ $logdate ]: packup_$dirname.tar.gz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$dirname".tar.gz | awk '{print $1}'))" >> "$logpath"/$logfile
    chmod 600 "$backuppath"/packup_"$dirname".tar.gz
else
    echo "Backup exited with errors and the zipfile was deleted :("
    echo "[ $logdate ]: Backup exited with errors and the tarfile was deleted :(" >> "$logpath"/$logfile
   #echo "BACKUP FAILED!" | mail -s "Backup has failed! Check $logpath/$logfile for the full log!" mail@example.com
    
    if [ -f "$backuppath"/packup_"$dirname".tar.gz ]; then
        rm -rf "$backuppath"/packup_"$dirname".tar.gz
    fi
    
    if [ -s "$logpath"/temp_backups_error.log ]; then
        {
        echo "Encountered the following errors:"
        cat "$logpath"/temp_backups_error.log
        echo "" 
        } >> "$logpath"/$logfile
    fi
    
    if [ -f "$logpath"/temp_backups_error.log ]; then
        rm -f "$logpath"/temp_backups_error.log
    fi
fi

# If the remote backup path is mounted, unmount it
if [ "$unmountwhenfinished" = "true" ]; then
    if mount | grep -q "$backuppath .*$mountpath"; then
        umount "$mountpath"
        echo "Unmounted remote path successfully"
    else
        echo "Remote path seems to be unmounted already... Skipping unmounting"
    fi
fi
# if "remotebackuppath" = "true" and "mount | grep -q "$backuppath .*$mountpath"" returns a string then run "umount $mountpath"


# Check for backups older than 3 months inside $backuppath and delete them
# DANGEROUS! UNCOMMENT WITH CAUTION AND AT YOUR OWN RISK (I take no responsibility for any data loss)
# find $backuppath -type f -mtime +90 -exec rm -f {} \;
exit 0
