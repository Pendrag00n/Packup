#!/bin/bash
# ______  ___  _____  _   ___   _______
# | ___ \/ _ \/  __ \| | / / | | | ___ \
# | |_/ / /_\ \ /  \/| |/ /| | | | |_/ /
# |  __/|  _  | |    |    \| | | |  __/
# | |   | | | | \__/\| |\  \ |_| | |
# \_|   \_| |_/\____/\_| \_/\___/\_|

# LIGHTWEIGHT BACKUP SCRIPT
# https://github.com/Pendrag00n/Packup
# ShellCheck Standards Compliant

#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
#        CONFIGURATION
#     (Modify accordingly)

# General variables:
backuppath="/var/packup"                  # Path where the backup will be stored. You can use a remote path by using the format //ip/share
logpath="/home/$SUDO_USER"                # Path to the log file
logfile="packup.log"                      # Name of the log file
files="/etc/ /home/$SUDO_USER/Documents/" # Enter files/folders separated by a space
backuppermission="0600"                   # Permission of the backup file (Use 4 digits)

# Incremental backup variables:
incremental="false" # If set to true, the backup will be incremental and will use rsync instead of tar

# Send email when something goes wrong: (Make sure you have correctly set up a MTA on your system)
sendemail="false"                  # If set to true, an email will be sent when something goes wrong
destination="receiver@example.com" # Email address where the email will be sent
subject="BACKUP FAILED!"           # Subject of the email
sendonsuccess="false"              # If set to true, an email will be sent when the backup is finished

# Remote backup variables:
mountpath="/home/$SUDO_USER/packuptmp" # This variable is only used if backup up to a remote location
mountport="445"                        # Default SMB/CIFS port
unmountwhenfinished="true"             # If set to true, the remote path will be unmounted when the backup is finished

# Delete old backups:
deleteoldbackups="false" # If set to true, old backups will be deleted
olderthan="90"           # (Expressed in days) If $deleteoldbackups is set to true, this variable will be used to determine how old the backups should be before they are deleted

#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

# Variables used for formatting the time and date
dirname=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

# Test if the log path and log file exists
if [ ! -d "$logpath" ]; then
    mkdir -p "$logpath"
fi
if [ ! -f "$logpath"/$logfile ]; then
    touch "$logpath"/$logfile
fi

# Test if boolean variables are set to true or false
if [ "$incremental" = "true" ]; then
    dirname="packup_inc"
elif ! [ "$incremental" = "false" ]; then
    echo "ERROR: $incremental is not a valid value for incremental (true/false). Exiting script..." >>"$logpath"/$logfile
    echo "ERROR: $incremental is not a valid value for incremental (true/false). Exiting script..."
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! ($incremental is not a valid value for incremental) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
    fi
    exit 2
fi
# if $unmountwhenfinished is something else than true or false then set it to false
if ! [ "$unmountwhenfinished" = "true" ] && ! [ "$unmountwhenfinished" = "false" ]; then
    unmountwhenfinished="false"
fi
# If $sendonsuccess is something else than true or false then set it to false
if ! [ "$sendonsuccess" = "true" ] && ! [ "$sendonsuccess" = "false" ]; then
    sendonsuccess="false"
fi

# If $backuppath starts with // then set $remotebackuppath to true
remotebackuppath="false"
if [ ${backuppath:0:2} = "//" ]; then
    remotebackuppath="true"
fi
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
        echo "ERROR: $file can't be located. Exiting script" >>"$logpath"/$logfile
        echo "ERROR: $file can't be located. Exiting script"
        if [ $sendemail = "true" ]; then
            echo "Backup has failed! ($file can't be located) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
        exit 2
    fi
done

# Check if $deleteoldbackups is a number greater than 1
if [ "$deleteoldbackups" = "true" ] && ! [[ $olderthan =~ ^[0-9]+$ ]] && test $olderthan -le 1; then
    echo "ERROR: $olderthan is not a valid number. Exiting script..." >>"$logpath"/$logfile
    echo "ERROR: $olderthan is not a valid number. Exiting script..."
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! ($olderthan is not a valid number) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
    fi
    exit 2
fi

# Check if tar is installed
if ! which tar >/dev/null; then
    echo "tar was not installed and is being installed now"
    apt install tar -y
    echo "[ $logdate ]: tar was not installed and was automatically installed" >>"$logpath"/$logfile
fi

# Check if rsync is installed
if [ "$incremental" = "true" ] && ! which rsync >/dev/null; then
    echo "rsync was not installed and is being installed now"
    apt install rsync -y
    echo "[ $logdate ]: rsync was not installed and was automatically installed" >>"$logpath"/$logfile
fi

# Test credentials file (ales.txt) and mount backup path
if [ "$remotebackuppath" = "true" ]; then
    if [ -f ales.txt ]; then
        chown root:root ales.txt
        chmod 0600 ales.txt
        # Test if the IP provided has port 445 enabled
        IP=$(echo "$backuppath" | cut -d/ -f3)
        echo "Testing if share is up on port 445..."
        if echo "Q" | nc -w 5 "$IP" $mountport >/dev/null; then
            echo "Share is up on port $mountport !"
        else
            echo "Error: Network share doesn't seem to be up on port $mountport :( Exiting script..."
            echo "Error: Network share doesn't seem to be up on port $mountport :( Exiting script..." >>"$logpath"/$logfile
            if [ $sendemail = "true" ]; then
                echo "Backup has failed! (Network share doesn't seem to be up on port $mountport) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
            fi
            exit 2
        fi

        # Check if the mountpath exists, if not, create it.
        if [ ! -d "$mountpath" ]; then
            mkdir -p "$mountpath"
        fi
        chown root:root "$mountpath"
        chmod 0600 "$mountpath"
        # Check if the backup path is already mounted
        if mount | grep -q "$backuppath .*$mountpath"; then
            echo "Drive seems to be mounted to the mountpath already!"
        else
            # Mount the network drive location into the mountpath
            echo "Mounting remote path..."
            mount -t cifs "$backuppath" "$mountpath" -o credentials="$PWD"/ales.txt &>"$logpath"/temp_mount_error.log
            # if temp_mount_error.log exists, change it's permissions to 0600
            if [ -f "$logpath"/temp_mount_error.log ]; then
                chown root:root "$logpath"/temp_mount_error.log
                chmod 0600 "$logpath"/temp_mount_error.log
            fi
            sleep 1 # Should work without this line
            if ! mount -t cifs "$backuppath" "$mountpath" -o credentials="$PWD"/ales.txt; then
                echo "The remote path could not be mounted :( Exiting script"
                {
                    echo "[ $logdate ]: The remote path could not be mounted :( Exiting script"
                    echo -n "Reasons for failure:"
                    cat "$logpath"/temp_mount_error.log
                } >>"$logpath"/$logfile
                if [ $sendemail = "true" ]; then
                    echo "Backup has failed! (Couldn't mount remote path) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
                fi
                exit 2
            fi

            # If temp_mount_error.log is not empty, delete it
            if [ -s "$logpath"/temp_mount_error.log ]; then
                rm "$logpath"/temp_mount_error.log
            fi
        fi
    else
        echo "The credentials file (ales.txt) was not found, place it alongside this script :( Exiting script"
        echo "[ $logdate ]: The credentials file (ales.txt) was not found, place it alongside this script :( Exiting script" >>"$logpath"/$logfile
        if [ $sendemail = "true" ]; then
            echo "Backup has failed! (Credentials file not found) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
        exit 2
    fi
fi

if [ ! -d "$backuppath" ]; then
    mkdir -p "$backuppath"
fi

# Do the correct type of backup and determine if it failed or not
failed="false"
if [ "$remotebackuppath" = "true" ]; then
    if [ "$incremental" = "true" ]; then
        rsync -avz --backup --backup-dir="$mountpath" "$files" "$mountpath"/"$dirname".tgz
        if ! rsync -avz --backup --backup-dir="$mountpath" "$files" "$mountpath"/"$dirname".tgz; then
            failed="true"
        fi
    else
        tar -czpf "$mountpath"/packup_"$dirname".tgz "$files" &>"$logpath"/temp_backups_error.log
        backuppath=$mountpath
        if ! tar -czpf "$mountpath"/packup_"$dirname".tgz "$files"; then
            failed="true"
        fi
    fi
else
    if [ "$incremental" = "true" ]; then
        rsync -avz --backup --backup-dir="$backuppath" "$files" "$backuppath"/"$dirname".tgz
        if ! rsync -avz --backup --backup-dir="$backuppath" "$files" "$backuppath"/"$dirname".tgz; then
            failed="true"
        fi
    else
        tar -czpf "$backuppath"/packup_"$dirname".tgz "$files" &>"$logpath"/temp_backups_error.log
        if ! tar -czpf "$backuppath"/packup_"$dirname".tgz "$files"; then
            failed="true"
        fi
    fi
fi

# Give information about the backup success or failure, set correct permissions and clean up
if [ "$failed" = "false" ]; then
    chmod $backuppermission "$backuppath"/packup_"$dirname".tgz
    echo "packup_$dirname.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$dirname".tgz | awk '{print $1}') )"
    echo "[ $logdate ]: packup_$dirname.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$dirname".tgz | awk '{print $1}'))" >>"$logpath"/$logfile
    chown root:root "$backuppath"/packup_"$dirname".tgz
    chmod 600 "$backuppath"/packup_"$dirname".tgz
    if [ "$sendonsuccess" = "true" ]; then
        echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$dirname".tgz | awk '{print $1}') ) " | mail -s "Backup Finished!" "$destination"
    fi
elif [ "$failed" = "true" ]; then
    echo "Backup exited with errors and the zipfile was deleted (Compression failed) :("
    echo "[ $logdate ]: Backup exited with errors and the tarfile was deleted (Compression failed) :(" >>"$logpath"/$logfile
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! (Compression failed) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
    fi

    # Remove incomplete backup
    if [ -f "$backuppath"/packup_"$dirname".tgz ]; then
        rm -rf "$backuppath"/packup_"$dirname".tgz
    fi

    # Send tar errors to the log file
    if [ -s "$logpath"/temp_backups_error.log ]; then
        {
            echo "Encountered the following errors:"
            cat "$logpath"/temp_backups_error.log
            echo ""
        } >>"$logpath"/$logfile
    fi

    # Remove the temp error log after being appended to the main log file
    if [ -f "$logpath"/temp_backups_error.log ]; then
        rm -f "$logpath"/temp_backups_error.log
    fi
fi

# If the remote backup path is mounted, unmount it
if [ "$remotebackuppath" = "true" ]; then
    if [ "$unmountwhenfinished" = "true" ]; then
        if mount | grep -q "$backuppath .*$mountpath"; then
            umount "$mountpath"
            echo "Unmounted remote path successfully"
        else
            echo "Remote path seems to be unmounted already... Skipping unmounting"
        fi
    fi
fi

# If $deleteoldbackups is set to true, check for backups older than $olderthan days inside $backuppath and delete them
if [ "$deleteoldbackups" = "true" ]; then
    echo "Deleting backups older than $olderthan days..."
    if ! [ -n "$TERM" ]; then
        echo ""
        echo "Are you sure?"
        echo press Y to continue, any other key to exit
        read -n 1 -r -p ""
        if [ "$REPLY" != "Y" ]; then
            echo "Nothing was deleted, exiting script..."
            exit 0
        fi
    fi
    find "$backuppath" -type f -name "*pdg*.tgz" -mtime +$olderthan -delete
fi

exit 0
