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
	files="/etc/ /home/pendragon/" # Enter files/folders separated by a space
	compressionlvl="6" # Where 0 is no compression and 9 is maximum compression (6 is default)
#////////////////////////////////////

# Start script
if ! which zip >/dev/null; then
	apt install zip -y
	echo "[ $logdate ]: zip was automatically installed" >> $logpath/backups.log
fi
if [ ! -d $backuppath ]; then
	mkdir -p $backuppath
    exit
fi

zip -r -$compressionlvl $backuppath/pdgbackup_$dirname.zip $files &> $logpath/temp_backups_error.log

if [ $? -eq 0 ]; then
    echo "[ $logdate ]: pdgbackup_$dirname.zip was created in $backuppath" >> $logpath/backups.log
else
    echo "[ $logdate ]: Backup exited with errors and the zipfile was deleted :(" >> $logpath/backups.log
    if [ -f $backuppath/pdgbackup_$dirname.zip ]; then
        rm -rf $backuppath/pdgbackup_$dirname.zip
    fi
    if [ -s $logpath/temp_backups_error.log ]; then
        echo "Encountered the following errors:" >> $logpath/backups.log
        grep "zip warning:" $logpath/temp_backups_error.log >> $logpath/backups.log
	echo ""
    fi
    if [ -f $logpath/temp_backups_error.log ]; then
        rm -f $logpath/temp_backups_error.log
    fi
fi
