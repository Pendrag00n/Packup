#!/bin/bash

#
# PDGBCKP
# LIGHTWEIGHT (AND PRIMITIVE) BACKUP TOOL
#

dirname=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

#////////////////////////////////////
# VARS (Modify accordingly)
backuppath="/var/backups/pendragon"
logpath="/home/pendragon"
# Enter files/folders separates by a space
files="/etc/ /home/pendragon/" # Enter files/folders separated by a space
compressionlvl="6" # Where 0 is no compression and 9 is maximum compression (6 is default)
#////////////////////////////////////

# Start script
if [ ! -d $backuppath ]; then
	mkdir -p $backuppath
    exit
fi

# Add below the folders/files you want to back up. In this case /etc/ and /home/pendragon/. Change compression level by adjusting the number "1-9"
    zip -r -$compressionlvl $backuppath/pdgbackup_$dirname.zip $files &> /dev/null

    if [ $? -eq 0 ]; then
        echo "[ $logdate ]: pdgbackup_$dirname.zip was created in $backuppath" >> $logpath/backups.log
    else
        echo "[ $logdate ]: Backup exited with errors and the zipfile was deleted :(" >> $logpath/backups.log
	if [ -f $backuppath/pdgbackup_$dirname.zip ]; then
            rm -rf $backuppath/pdgbackup_$dirname.zip
        fi
    fi
exit 0
