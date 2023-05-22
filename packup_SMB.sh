#!/bin/bash
# ______  ___  _____  _   ___   _______
# | ___ \/ _ \/  __ \| | / / | | | ___ \
# | |_/ / /_\ \ /  \/| |/ /| | | | |_/ /
# |  __/|  _  | |    |    \| | | |  __/
# | |   | | | | \__/\| |\  \ |_| | |
# \_|   \_| |_/\____/\_| \_/\___/\_|

# LIGHTWEIGHT BACKUP SCRIPT
# https://github.com/Pendrag00n/Packup (Adaptado a Agrucan)
# ShellCheck Standards Compliant

#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\
#
#        CONFIGURATION
#     (Modify accordingly)

# General variables:
backuppath="//192.168.117.225/smbshare" # Path where the backup will be stored. //server/share for SMB remote backups. Absolute path for SSH remote backups
logpath="/var/packup"                   # Path to the log file
logfile="packup.log"                    # Name of the log file
files=(/etc/ /bin/)                     # Enter files/folders separated by a space
restartservices=""                      # "" To disable. Stops these services before the backup and restarts them after the backup. (Use space to separate services)

# Incremental backup variables:
incremental="false" # If set to true, the backup will be incremental and will use rsync instead of tar

# Send email when something goes wrong: (Make sure you have correctly set up a MTA on your system. Ex: https://www.tutorialspoint.com/configure-postfix-to-use-gmail-smtp-on-ubuntu)
sendemail="false"                  # If set to true, an email will be sent when something goes wrong
destination="receiver@example.com" # Email address where the email will be sent
subject="BACKUP FAILED!"           # Subject of the email
sendonsuccess="false"              # If set to true, an email will be sent when the backup is finished

# Remote backup variables:
port="445"                    # Default SMB/CIFS port is 445. Default SSH port is 22
SMBmountpath="/var/packup"    # This variable is only used if backup up to a SMB remote location
SMBunmountwhenfinished="true" # If set to true, the remote path will be unmounted when the backup is finished

# Delete old backups:
deleteoldbackups="true" # If set to true, old backups will be deleted
olderthan="90"          # (Expressed in days) If $deleteoldbackups is set to true, this variable will be used to determine how old the backups should be before they are deleted

#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

# Variables used for formatting the time and date:
filetail=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

# Other variables:
#BASEDIR="$(dirname "$0")" # Path to the directory where the script is located
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# check if script is being ran as sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root" >>"$logpath"/$logfile
    echo "ERROR: Please run as root"
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! (Please run as root) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
    fi
    exit 1
fi

# Test if the log path and log file exists
if [ ! -d "$logpath" ]; then
    mkdir -p "$logpath"
fi
if [ ! -f "$logpath"/$logfile ]; then
    touch "$logpath"/$logfile
fi

# Test if boolean variables are set to true or false:º
# If $incremental is something else than true or false then set it to false
if ! [ "$incremental" = "true" ] && ! [ "$incremental" = "false" ]; then
    incremental="false"
fi

# if $SMBunmountwhenfinished is something else than true or false then set it to false
if ! [ "$SMBunmountwhenfinished" = "true" ] && ! [ "$SMBunmountwhenfinished" = "false" ]; then
    SMBunmountwhenfinished="false"
fi
# If $sendonsuccess is something else than true or false then set it to false
if ! [ "$sendonsuccess" = "true" ] && ! [ "$sendonsuccess" = "false" ]; then
    sendonsuccess="false"
fi

# If $backuppath starts with // then set $remotebackup to true
if [ ${backuppath:0:2} = "//" ]; then
    remotebackup="true"
fi
# If $backuppath ends with a /, remove it.
if [ ${backuppath: -1} = "/" ]; then
    backuppath=${backuppath::-1}
fi
# If $SMBmountpath ends with a /, remove it
if [ "${SMBmountpath: -1}" = "/" ]; then
    SMBmountpath=${SMBmountpath::-1}
fi
# If $logpath ends with a /, remove it
if [ ${logpath: -1} = "/" ]; then
    logpath=${logpath::-1}
fi

# Check if the files exist
for file in "${files[@]}"; do
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

# Check system packet manager
if which apt &>/dev/null; then
    install="apt install -y"
elif which yum &>/dev/null; then
    install="yum install -y"
elif which dnf &>/dev/null; then
    install="dnf install -y"
elif which zypper &>/dev/null; then
    install="zypper install -y"
elif which pacman &>/dev/null; then
    install="pacman -A --noconfirm"
elif which apk &>/dev/null; then
    install="apk add --no-cache"
elif which emerge &>/dev/null; then
    install="emerge -y"
else
    echo "ERROR: No packet manager found. Exiting script..." >>"$logpath"/$logfile
    echo "ERROR: No packet manager found. Exiting script..."
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! (No packet manager found) Check $logpath/$logfile for the full log" | mail -s "$subject" "$destination"
    fi
    exit 2
fi

# Check if tar is installed
if ! which tar >/dev/null; then
    echo "tar was not installed and is being installed now"
    $install tar
    if ! $install tar; then
        echo "ERROR: tar could not be installed. Exiting script..." >>"$logpath"/$logfile
        echo "ERROR: tar could not be installed. Exiting script..."
        if [ $sendemail = "true" ]; then
            echo "Backup has failed! (tar could not be installed) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
        exit 2
    fi
    echo "[ $logdate ]: tar was not installed and was automatically installed" >>"$logpath"/$logfile
fi

# Test credentials file (ales.txt) and mount backup path
if [ "$remotebackup" = "true" ]; then
    IP=$(echo "$backuppath" | cut -d/ -f3)
    echo "Testing if SMB is up on port $port..."
    if echo "Q" | nc -w 3 "$IP" "$port" >/dev/null; then
        echo "SMB is up on $IP on port $port !"
    else
        echo "Error: SMB doesn't seem to be up on $IP on port $port :( Exiting script..."
        echo "Error: SMB doesn't seem to be up on $IP on port $port :( Exiting script..." >>"$logpath"/$logfile
        if [ $sendemail = "true" ]; then
            echo "Backup has failed! (SMB doesn't seem to be up on $IP port $port) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
        exit 2
    fi

    # Test credentials file (ales.txt) and mount backup path
    if [ -f "$BASEDIR"/ales.txt ]; then
        chown root:root "$BASEDIR"/ales.txt
        chmod 0600 "$BASEDIR"/ales.txt
    else
        touch ales.txt
        echo $'username=\npassword=' >"$BASEDIR"/ales.txt
        chown root:root "$BASEDIR"/ales.txt
        chmod 0600 "$BASEDIR"/ales.txt
        echo "The credentials file (ales.txt) was not found, a template has been created in the script's dir, fill it :( Exiting script"
        echo "[ $logdate ]: The credentials file (ales.txt) was not found, a template has been created in the script's dir, fill it :( Exiting script" >>"$logpath"/$logfile
        exit 2
    fi
    # Check if the SMBmountpath exists, if not, create it.
    if [ ! -d "$SMBmountpath" ]; then
        mkdir -p "$SMBmountpath"
    fi
    chown root:root "$SMBmountpath"
    chmod 0600 "$SMBmountpath"
    # Check if the backup path is already mounted
    if mount | grep -q "$backuppath .*$SMBmountpath"; then
        echo "Drive seems to be mounted to the SMBmountpath already!"
    else

        # Test if cifs-utils is already installed, if not, install it
        if ! which mount.cifs >/dev/null; then
            echo "cifs-utils was not installed and is being installed now"
            $install cifs-utils
            if ! $install cifs-utils; then
                echo "ERROR: cifs-utils could not be installed. Exiting script..." >>"$logpath"/$logfile
                echo "ERROR: cifs-utils could not be installed. Exiting script..."
                if [ $sendemail = "true" ]; then
                    echo "Backup has failed! (cifs-utils could not be installed) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
                fi
                exit 2
            fi
            echo "[ $logdate ]: cifs-utils was not installed and was automatically installed" >>"$logpath"/$logfile
        fi

        # Mount the network drive location into the SMBmountpath
        echo "Mounting remote path... (This will take at least 10 seconds)"
        mount -t cifs "$backuppath" "$SMBmountpath" -o credentials="${BASEDIR}"/ales.txt &>"$logpath"/temp_mount_error.log
        sleep 10 # Wait 10 seconds for the mount to finish
        if ! mount -t cifs "$backuppath" "$SMBmountpath" -o credentials="${BASEDIR}"/ales.txt; then
            echo "The remote path could not be mounted :( Exiting script"
            {
                echo "[ $logdate ]: The remote path could not be mounted :( Exiting script"
                echo -n "Reasons for failure:"
                cat "$logpath"/temp_mount_error.log
                echo ""
            } >>"$logpath"/$logfile
            if [ $sendemail = "true" ]; then
                echo "Backup has failed! (Couldn't mount remote path) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
            fi
            exit 2
        fi
        # If temp_mount_error.log exists, delete it
        if [ -f "$logpath"/temp_mount_error.log ]; then
            rm "$logpath"/temp_mount_error.log
        fi
    fi
fi

if [ ! -d "$backuppath" ] || [ "$remotebackup" = "false" ]; then
    mkdir -p "$backuppath"
fi

# If requested, stop the services, then do the correct type of backup and determine if it failed or not
# (Spanned for better readability)
failed="false"
if [ -n "$restartservices" ]; then
    systemctl stop "$restartservices"
fi

if [ "$remotebackup" = "true" ]; then

    if [ "$incremental" = "true" ]; then

        tar -czpf "$SMBmountpath"/packup_"$filetail".tgz -g "$backuppath"/packup-snapshot.data "${files[@]}" &>"$logpath"/temp_backups_error.log

        if ! tar -czpf "$SMBmountpath"/packup_"$filetail".tgz -g "$backuppath"/packup-snapshot.data "${files[@]}"; then
            failed="true"
        fi

    else # If $incremental is false

        tar -czpf "$SMBmountpath"/packup_"$filetail".tgz "${files[@]}" &>"$logpath"/temp_backups_error.log

        if ! tar -czpf "$SMBmountpath"/packup_"$filetail".tgz "${files[@]}"; then
            failed="true"
        fi

    fi

else # If $remotebackup is false

    if [ "$incremental" = "true" ]; then

        tar -czpf "$backuppath"/packup_inc_"$filetail".tgz -g "$backuppath"/packup-snapshot.data "${files[@]}" &>"$logpath"/temp_backups_error.log

        if ! tar -czpf "$backuppath"/packup_inc_"$filetail".tgz -g "$backuppath"/packup-snapshot.data "${files[@]}"; then
            failed="true"
        fi

    else # If $incremental is false

        tar -czpf "$backuppath"/packup_"$filetail".tgz "${files[@]}" &>"$logpath"/temp_backups_error.log

        if ! tar -czpf "$backuppath"/packup_"$filetail".tgz "${files[@]}"; then
            failed="true"
        fi

    fi

fi

# Start the services again if they were stopped
if [ -n "$restartservices" ]; then
    systemctl start "$restartservices"
fi

# Give information about the backup success or failure, set correct permissions and clean up
if [ "$failed" = "false" ]; then

    if [ "$remotebackup" = "false" ]; then

        if [ "$incremental" = "true" ]; then
            chmod 0600 "$backuppath"/packup_inc_"$filetail".tgz
            chmod 0600 "$backuppath"/packup-snapshot.data
            chown root:root "$backuppath"/packup_inc_"$filetail".tgz
            chown root:root "$backuppath"/packup-snapshot.data
            echo "packup_inc_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_inc_"$filetail".tgz | awk '{print $1}'))"
            echo "[ $logdate ]: packup_inc_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_inc_"$filetail".tgz | awk '{print $1}'))" >>"$logpath"/$logfile
        else # If $incremental is false
            chmod 0600 "$backuppath"/packup_"$filetail".tgz
            chown root:root "$backuppath"/packup_"$filetail".tgz
            echo "packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$filetail".tgz | awk '{print $1}'))"
            echo "[ $logdate ]: packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$filetail".tgz | awk '{print $1}'))" >>"$logpath"/$logfile
        fi

    else # If $remotebackup is true

        if [ "$incremental" = "true" ]; then
            chmod 0600 "$SMBmountpath"/packup_inc_"$filetail".tgz
            chmod 0600 "$SMBmountpath"/packup-snapshot.data
            chown root:root "$SMBmountpath"/packup_inc_"$filetail".tgz
            chown root:root "$SMBmountpath"/packup-snapshot.data
            echo "packup_inc_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$SMBmountpath"/packup_inc_"$filetail".tgz)"
            echo "[ $logdate ]: packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$SMBmountpath"/packup_inc_"$filetail".tgz))" >>"$logpath"/$logfile
        else # If $incremental is false
            chmod 0600 "$SMBmountpath"/packup_"$filetail".tgz
            chown root:root "$SMBmountpath"/packup_"$filetail".tgz
            echo "packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$SMBmountpath"/packup_"$filetail".tgz)"
            echo "[ $logdate ]: packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$SMBmountpath"/packup_"$filetail".tgz))" >>"$logpath"/$logfile
        fi

    fi

fi

# Send mail if requested
if [ "$sendonsuccess" = "true" ]; then
    if [ "$remotebackup" = "true" ]; then
        if [ "$incremental" = "true" ]; then
            echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $(du -sh "$SMBmountpath"/packup_inc_"$filetail".tgz | awk '{print $1}')) " | mail -s "Backup Finished!" "$destination"
        else
            echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $(du -sh "$SMBmountpath"/packup_"$filetail".tgz | awk '{print $1}')) " | mail -s "Backup Finished!" "$destination"
        fi
    else # If $remotebackup is false
        if [ "$incremental" = "true" ]; then
            echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_inc_"$filetail".tgz | awk '{print $1}')) " | mail -s "Backup Finished!" "$destination"
        else
            echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$filetail".tgz | awk '{print $1}')) " | mail -s "Backup Finished!" "$destination"
        fi
    fi
fi

if [ "$failed" = "true" ]; then
    echo "Backup exited with errors and the zipfile was deleted (Compression failed) :("
    echo "[ $logdate ]: Backup exited with errors and the tarfile was deleted (Compression failed) :(" >>"$logpath"/$logfile
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! (Tar failed) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
    fi
    if [ "$remotebackup" = "false" ]; then
        # Remove incomplete backup
        if [ -f "$backuppath"/packup_"$filetail".tgz ]; then
            rm -rf "$backuppath"/packup_"$filetail".tgz
        fi

    fi
    # Send tar errors to the log file
    if [ -s "$logpath"/temp_backups_error.log ]; then
        {
            echo "Encountered the following tar errors:"
            cat "$logpath"/temp_backups_error.log
            echo ""
        } >>"$logpath"/$logfile
    fi

    # Remove the temp error log after being appended to the main log file
    if [ -f "$logpath"/temp_backups_error.log ]; then
        rm -f "$logpath"/temp_backups_error.log
    fi
fi

# If $deleteoldbackups is set to true, check for backups older than $olderthan days inside $backuppath and delete them
if [ "$deleteoldbackups" = "true" ]; then
    echo "Deleting backups older than $olderthan days..."
    if [ -z "$TERM" ]; then
        echo ""
        echo "Are you sure?"
        echo press Y to continue, any other key to exit
        read -n 1 -r -p ""
        if [ "$REPLY" != "Y" ]; then
            echo "Nothing was deleted, exiting script..."
            exit 0
        fi
    fi
    if [ "$remotebackup" = "true" ]; then
        if [ "$incremental" = "true" ]; then
            find "$SMBmountpath" -maxdepth 1 -type f -name "packup_inc_*.tgz" -mtime +$olderthan -delete
        else # If $incremental is false
            find "$SMBmountpath" -maxdepth 1 -type f -name "packup_*.tgz" -mtime +$olderthan -delete
        fi
    else # If $remotebackup is false
        if [ "$incremental" = "true" ]; then
            find "$backuppath" -maxdepth 1 -type f -name "packup_inc_*.tgz" -mtime +$olderthan -delete
        else # If $incremental is false
            find "$backuppath" -maxdepth 1 -type f -name "packup_*.tgz" -mtime +$olderthan -delete
        fi
    fi
fi

# If the remote backup path is mounted, unmount it
if [ "$remotebackup" = "true" ] && [ "$SMBunmountwhenfinished" = "true" ]; then
    attempt=1
    while mount | grep -q "$backuppath .*$SMBmountpath"; do
        echo "Attempt number $attempt on unmounting the SMB share from the system."
        attempt=$((attempt + 1))
        umount "$SMBmountpath"
        sleep 2 # Optional delay before checking again
    done
    if mount | grep -q "$backuppath .*$SMBmountpath"; then
        echo "Failed to unmount the SMB share from the system."
        echo "[ $logdate ]: Failed to unmount the SMB share from the system." >>"$logpath"/$logfile
        if [ "$sendemail" = "true" ]; then
            echo "Failed to unmount the SMB share from the system. Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
    else
        echo "Remote path unmounted successfully."
    fi
fi

exit 0
