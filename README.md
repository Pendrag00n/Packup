# Packup
LIGHTWEIGHT BACKUP TOOL INTENDED TO BE RUN BY CRON (CAN ALSO BE RUN MANUALLY)

## USAGE
**Running manually**
* Modify the variables inside the script according to your needs and execute:
`sudo bash packup.sh` 

**Running from cron**
* Store the script (alongside *ales.txt* if needed for remote backups) inside a folder used for cron scripts (or dont), for example, */usr/scripts/*.
* Modify the variables inside the script according to your needs.
* Open root's crontab by running `sudo crontab -e` (Running this as another user WILL cause the backup to fail due to permissions issues).
* Configure the scheduled job to run the script. For example: 
`0 3 * * 1 /bin/bash /usr/scripts/weeklybckp.sh` 
executes the backup every monday at 3 a.m
