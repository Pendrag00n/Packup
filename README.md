# Packup
LIGHTWEIGHT (AND PRIMITIVE) BACKUP TOOL INTENDED TO BE RUN BY CRON

## USAGE
* Store the script inside a folder used for cron scripts (or dont), for example, */usr/scripts/*.
* Modify the variables inside the script according to your needs.
* Open root's crontab by running `sudo crontab -e` (Running this as another user may cause the backup to fail due to permissions, but it's not mandatory)
* Configure the scheduled job to run the script. For example: `0 3 * * 1 /bin/bash /usr/scripts/weeklybckp.sh` executes the backup every monday at 3 a.m
