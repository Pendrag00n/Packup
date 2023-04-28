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
backuppath="/var/packup"                # Path where the backup will be stored. //server/share for SMB remote backups. Absolute path for SSH remote backups
logpath="/home/julio"                   # Path to the log file
logfile="packup.log"                    # Name of the log file
files=(/etc/ /bin/ /home/julio/Videos/) # Enter files/folders separated by a space
backuppermission="0600"                 # Permission of the backup file (Use 4 digits)
restartservices=""                      # "" To disable. Stops these services before the backup and restarts them after the backup. (Use space to separate services)

# Incremental backup variables:
incremental="true" # If set to true, the backup will be incremental and will use rsync instead of tar

# Send email when something goes wrong: (Make sure you have correctly set up a MTA on your system. Ex: https://www.tutorialspoint.com/configure-postfix-to-use-gmail-smtp-on-ubuntu)
sendemail="false"                  # If set to true, an email will be sent when something goes wrong
destination="receiver@example.com" # Email address where the email will be sent
subject="BACKUP FAILED!"           # Subject of the email
sendonsuccess="false"              # If set to true, an email will be sent when the backup is finished

# Remote backup variables:
remotebackup="true"                       # If set to true, the backup will be stored on a remote location
method="rsync"                            # (rsync or smb) Method used to backup to a remote location
port="22"                                 # Default SMB/CIFS port is 445. Default SSH port is 22
SMBmountpath="/home/$SUDO_USER/packuptmp" # This variable is only used if backup up to a SMB remote location
SMBunmountwhenfinished="true"             # If set to true, the remote path will be unmounted when the backup is finished
SSHusername="julio"                       # Username used to connect to the remote server
SSHip="192.168.117.137"                   # IP address of the remote server

# Delete old backups:
deleteoldbackups="false" # If set to true, old backups will be deleted
olderthan="90"           # (Expressed in days) If $deleteoldbackups is set to true, this variable will be used to determine how old the backups should be before they are deleted

#/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\

# Variables used for formatting the time and date:
filetail=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

# Other variables:
BASEDIR=$(dirname $0) # Path to the directory where the script is located

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

# Test if boolean variables are set to true or false
if [ "$incremental" = "true" ]; then
    filetail="inc"
elif ! [ "$incremental" = "false" ]; then
    echo "ERROR: $incremental is not a valid value for incremental (true/false). Exiting script..." >>"$logpath"/$logfile
    echo "ERROR: $incremental is not a valid value for incremental (true/false). Exiting script..."
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! ($incremental is not a valid value for incremental) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
    fi
    exit 2
fi
# if $SMBunmountwhenfinished is something else than true or false then set it to false
if ! [ "$SMBunmountwhenfinished" = "true" ] && ! [ "$SMBunmountwhenfinished" = "false" ]; then
    SMBunmountwhenfinished="false"
fi
# If $sendonsuccess is something else than true or false then set it to false
if ! [ "$sendonsuccess" = "true" ] && ! [ "$sendonsuccess" = "false" ]; then
    sendonsuccess="false"
fi

# If $backuppath starts with // then set $method to smb
if [ ${backuppath:0:2} = "//" ]; then
    method="smb"
fi
# If $backuppath ends with a /, remove it.
if [ ${backuppath: -1} = "/" ]; then
    backuppath=${backuppath::-1}
fi
# If $SMBmountpath ends with a /, remove it
if [ ${SMBmountpath: -1} = "/" ]; then
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
if which apt >/dev/null; then
    install="apt install -y"
elif which yum >/dev/null; then
    install="yum install -y"
elif which dnf >/dev/null; then
    install="dnf install -y"
elif which zypper >/dev/null; then
    install="zypper install -y"
elif which pacman >/dev/null; then
    install="pacman -A --noconfirm"
elif which apk >/dev/null; then
    install="apk add --no-cache"
elif which emerge >/dev/null; then
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

# Check if rsync is installed
if [ "$remotebackup" = "true" ] && ! which rsync >/dev/null; then
    echo "rsync was not installed and is being installed now"
    $install rsync
    if ! $install rsync; then
        echo "ERROR: rsync could not be installed. Exiting script..." >>"$logpath"/$logfile
        echo "ERROR: rsync could not be installed. Exiting script..."
        if [ $sendemail = "true" ]; then
            echo "Backup has failed! (rsync could not be installed) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
        exit 2
    fi
    echo "[ $logdate ]: rsync was not installed and was automatically installed" >>"$logpath"/$logfile
fi

# Test credentials file (ales.txt) and mount backup path
if [ "$remotebackup" = "true" ]; then

    # Test if the IP provided has SSH/SMB running on the defined port
    if [ "$method" = "smb" ]; then
        IP=$(echo "$backuppath" | cut -d/ -f3)
    elif [ "$method" = "rsync" ]; then
        IP=$SSHip
    fi
    echo "Testing if SSH is up on port $port..."
    if echo "Q" | nc -w 5 "$IP" "$port" >/dev/null; then
        echo "SSH/SMB is up on port $port !"
    else
        echo "Error: SSH/SMB doesn't seem to be up on port $port :( Exiting script..."
        echo "Error: SSH/SMB doesn't seem to be up on port $port :( Exiting script..." >>"$logpath"/$logfile
        if [ $sendemail = "true" ]; then
            echo "Backup has failed! (SSH/SMB doesn't seem to be up on port $port) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
        fi
        exit 2
    fi

    # Test credentials file (ales.txt) and mount backup path
    if [ "$method" = "smb" ]; then
        if [ -f "${BASEDIR}"ales.txt ]; then
            chown root:root "${BASEDIR}"ales.txt
            chmod 0600 "${BASEDIR}"ales.txt
        else
            touch ales.txt
            echo $'username=\npassword=' >"${BASEDIR}"/ales.txt
            chown root:root "${BASEDIR}"ales.txt
            chmod 0600 "${BASEDIR}"ales.txt
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
            # Mount the network drive location into the SMBmountpath
            echo "Mounting remote path..."
            mount -t cifs "$backuppath" "$SMBmountpath" -o credentials="$PWD"/ales.txt &>"$logpath"/temp_mount_error.log
            # if temp_mount_error.log exists, change it's permissions to 0600
            if [ -f "$logpath"/temp_mount_error.log ]; then
                chown root:root "$logpath"/temp_mount_error.log
                chmod 0600 "$logpath"/temp_mount_error.log
            fi
            sleep 1 # Should work without this line
            if ! mount -t cifs "$backuppath" "$SMBmountpath" -o credentials="$PWD"/ales.txt; then
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
    fi
fi

if [ ! -d "$backuppath" ]; then
    mkdir -p "$backuppath"
fi

#If requested, stop the services, then do the correct type of backup and determine if it failed or not
failed="false"
if [ -n "$restartservices" ]; then
    systemctl stop "$restartservices"
fi
if [ "$remotebackup" = "true" ]; then
    if [ "$incremental" = "true" ]; then
        if [ $method = "rsync" ]; then
            lastbackuppath=$(ls -td $backuppath/packup_* | head -n 1)
            rsync -avz --link-dest="$lastbackuppath" "${files[@]}" $SSHusername@$SSHip:"$backuppath"/packup_inc"$filetail"/ 2>"$logpath"/temp_backups_error.log
            if ! rsync -avz --link-dest="$lastbackuppath" "${files[@]}" $SSHusername@$SSHip:"$backuppath"/packup_inc"$filetail"/; then
                failed="true"
            fi
        fi
        if [ $method = "smb" ]; then
            tar -czpf "$SMBmountpath"/packup_"$filetail".tgz -g "$backuppath"/packup-incremental-data "${files[@]}" &>"$logpath"/temp_backups_error.log
            if ! tar -czpf "$SMBmountpath"/packup_"$filetail".tgz "${files[@]}"; then
                failed="true"
            fi
        fi
    fi
    if [ "$incremental" = "false" ]; then
        if [ $method = "rsync" ]; then
            rsync -avz --relative "${files[@]}" $SSHusername@$SSHip:"$backuppath"/packup_"$filetail" 2>"$logpath"/temp_backups_error.log | tail -1 | cut -d " " -f 4 >"$logpath"/backup_size.log && rsize=$(cat backup_size.log)
            rm "$logpath"/backup_size.log
            if ! rsync -avz --relative "${files[@]}" $SSHusername@$SSHip:"$backuppath"/packup_"$filetail"; then
                failed="true"
            fi
        fi
        if [ $method = "smb" ]; then
            tar -czpf "$SMBmountpath"/packup_"$filetail".tgz "${files[@]}" &>"$logpath"/temp_backups_error.log
            if ! tar -czpf "$SMBmountpath"/packup_"$filetail".tgz "${files[@]}"; then
                failed="true"
            fi
        fi
    fi
fi
if [ "$remotebackup" = "false" ]; then
    if [ "$incremental" = "true" ]; then
        tar -czpf "$backuppath"/packup_inc_"$filetail".tgz -g "$backuppath"/packup-incremental-data "${files[@]}" &>"$logpath"/temp_backups_error.log
        if ! tar -czpf "$backuppath"/packup_inc_"$filetail".tgz -g "$backuppath"/packup-incremental-data "${files[@]}"; then
            failed="true"
        fi
    fi
    if [ "$incremental" = "false" ]; then
        tar -czpf "$backuppath"/packup_"$filetail".tgz "${files[@]}" &>"$logpath"/temp_backups_error.log
        if ! tar -czpf "$backuppath"/packup_"$filetail".tgz "${files[@]}"; then
            failed="true"
        fi
    fi
fi

if [ -n "$restartservices" ]; then
    systemctl start "$restartservices"
fi

# Give information about the backup success or failure, set correct permissions and clean up
if [ "$failed" = "false" ] && [ "$remotebackup" = "false" ]; then
    chmod $backuppermission "$backuppath"/packup_"$filetail".tgz
    echo "packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$filetail".tgz | awk '{print $1}'))"
    echo "[ $logdate ]: packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$filetail".tgz | awk '{print $1}'))" >>"$logpath"/$logfile
    chown root:root "$backuppath"/packup_"$filetail".tgz
    chmod 600 "$backuppath"/packup_"$filetail".tgz
fi

if [ "$failed" = "false" ] && [ "$remotebackup" = "true" ]; then # Fix filesize (and permissions)
    echo "packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $rsize)"
    echo "[ $logdate ]: packup_$filetail.tgz was created in $backuppath (Took $SECONDS seconds and weighs $rsize)" >>"$logpath"/$logfile
fi

if [ $remotebackup = "false" ] && [ "$incremental" = "true" ]; then
    chown root:root "$backuppath"/packup-incremental-data
    chmod 600 "$backuppath"/packup-incremental-data
fi
if [ "$sendonsuccess" = "true" ]; then
    if [ "$remotebackup" = "true" ]; then
        echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $rsize" | mail -s "Backup Finished!" "$destination"
    else
        echo "Backup has finished successfully on $(date | cut -d " " -f 1-4)! Took $SECONDS seconds and weighs $(du -sh "$backuppath"/packup_"$filetail".tgz | awk '{print $1}')) " | mail -s "Backup Finished!" "$destination"
    fi
fi

if [ "$failed" = "true" ]; then
    echo "Backup exited with errors and the zipfile was deleted (Compression failed) :("
    echo "[ $logdate ]: Backup exited with errors and the tarfile was deleted (Compression failed) :(" >>"$logpath"/$logfile
    if [ $sendemail = "true" ]; then
        echo "Backup has failed! (Compression failed) Check $logpath/$logfile for the full log!" | mail -s "$subject" "$destination"
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
if [ "$remotebackup" = "true" ] && [ "$SMBunmountwhenfinished" = "true" ]; then
    if mount | grep -q "$backuppath .*$SMBmountpath"; then
        umount "$SMBmountpath"
        echo "Unmounted remote path successfully"
    elif ! umount "$SMBmountpath"; then
        echo "Unmounting remote path failed, please unmount it manually"
        ecgo "[ $logdate ]: Unmounting remote path failed, please unmount it manually" >>"$logpath"/$logfile
    else
        echo "Remote path seems to be unmounted already... Skipping unmounting"
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
    find "$backuppath" -type f -name "packup_*.tgz" -maxdepth 1 -mtime +$olderthan -delete
fi

exit 0
