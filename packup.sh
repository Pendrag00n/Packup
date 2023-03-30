#!/bin/bash

#
# PDGBCKP
# LIGHTWEIGHT BACKUP TOOL
#

#//////////////////////////////
#	CONFIGURATION
#    (Modify accordingly)

	backuppath="//192.168.1.2/share" # Path where the backup will be stored
		remotebackuppath="true" # Set to true if you are backing up to a remote path
		mountpath="/tmp/packup" # Only used if remotebackuppath is set to true
	logpath="/home/julio" # Path to the log file
	files="/etc/" # Enter files/folders separated by a space
	compressionlvl="4" # Where 1 is no compression and 9 is maximum compression (6 is default)

#///////////////////////////////

dirname=$(date +%d-%m-%Y_%H-%M-%S)
logdate=$(date +%d-%m-%Y)

# Start script
if ! which tar >/dev/null; then
	apt install tar -y
	echo "tar was surprisingly not installed and is being installed now"
	echo "[ $logdate ]: tar was surprisingly not installed and was automatically installed" >> $logpath/backups.log
fi

if [ ! -d $backuppath ]; then
	mkdir -p $backuppath
    exit
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
		SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
		mount -t smbclient $backuppath $mountpath -o credentials=$SCRIPT_DIR/ales.txt
		sleep 4 #Should work without this line
	else
		echo "The credentials file (ales.txt) was not found :( Exiting script"
		echo "[ $logdate ]: The credentials file (ales.txt) was not found :( Exiting script" >> $logpath/backups.log
		exit 2
	fi
fi

if [ $? -ne 0 ]; then
	echo "The remote path could not be mounted :( Exiting script"
	echo "[ $logdate ]: The remote path could not be mounted :( Exiting script" >> $logpath/backups.log
	exit
fi

# zip -r -$compressionlvl $backuppath/packup_$dirname.zip $files &> $logpath/temp_backups_error.log
tar -czf -$compressionlvl $backuppath/packup_$dirname.tar.gz $files &> $logpath/temp_backups_error.log


if [ $? -eq 0 ]; then
	echo "packup_$dirname.zip was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh $backuppath/packup_$dirname.zip | awk '{print $1}') )"
	echo "[ $logdate ]: packup_$dirname.zip was created in $backuppath (Took $SECONDS seconds and weighs $(du -sh $backuppath/packup_$dirname.zip | awk '{print $1}'))" >> $logpath/backups.log
	chmod 600 $backuppath/packup_$dirname.zip
else
	echo "Backup exited with errors and the zipfile was deleted :("
	echo "[ $logdate ]: Backup exited with errors and the zipfile was deleted :(" >> $logpath/backups.log

	if [ -f $backuppath/packup_$dirname.zip ]; then
        	rm -rf $backuppath/packup_$dirname.zip
	fi

	if [ -s $logpath/temp_backups_error.log ]; then
		echo "Encountered the following errors:" >> $logpath/backups.log
		grep "zip warning:" $logpath/temp_backups_error.log >> $logpath/backups.log
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
