#!/usr/bin/env bash
#
# Copyright S. Hesterberg, 2016
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING. If not, write to the
# Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#
# Author: Scott C. Hesterberg <scotthesterberg@users.noreply.github.com>


#pull sensitive variables for this script from variable definition file
if [ -f ./variables.txt ]; then
	source ./variables.txt
else
	MAIL="Variables definition file missing! As a result ZFS backup could not be run"
	printf "$MAIL" | mail -s "ZFS backup failed!" $email
	exit 1
fi

#~/cron_scripts/zfs_destroy_backed_up_snapshots.sh

#initialize variables
#email=youremail
#store_server=zfsfilestoreserverip/dns
#store_pool_name=storagezfsserverpoolname
#store_filesystem_name=storagezfsserverfilesystemname
#backup_pool_name=backupzfsserverpoolname
#backup_filesystem_name=backupezfsserverfilesystemname

#store list of snapshots on backup server
/sbin/zfs list -Hr -t snap $backup_pool_name/$store_fileshare_name 2> /tmp/zfs_list_err | /bin/awk '{print $1}' | /bin/awk -F / '{print $2}' | /bin/sort -r > /tmp/back_snaps

#store list of snapshots on storage server
/bin/ssh -i $ssh_backup_key $store_server "~/cron_scripts/zfs_destroy_storage_snaps.sh && /sbin/zfs list -Hr -t snap $store_pool_name/$store_fileshare_name " 2> /tmp/ssh_std_err | /bin/awk '{print $1}' | /bin/awk -F / '{print $2}' > /tmp/store_snaps

#find latest storage server snapshot
#to be sent with all predecessors created since last backup to backup server
latest_snap=$(tail -n 1 /tmp/store_snaps)

#test to see if we were successful in listing snapshots
if [[ ! -s /tmp/ssh_std_err && ! -s /tmp/zfs_list_err ]]; then
	#find common snapshot on backup and storage servers
	/bin/grep -F -x -f /tmp/back_snaps /tmp/store_snaps > /tmp/common_snaps
	#sort snapshots from previous command by date and add latest common snap to common_snap variable
	common_snap=$(grep $(/bin/cat /tmp/common_snaps | /bin/cut -d "-" -f4-6 | /bin/sort | /bin/tail -n 1) /tmp/common_snaps)
	#delete error files
	/bin/rm -f /tmp/ssh_std_err /tmp/zfs_list_err /tmp/common_snaps
else
	MAIL="ZFS list $store_server snapshots FAILED! Error:"
	/bin/printf "$MAIL \n ssh output:\n $( /bin/cat /tmp/ssh_std_err) \n\
	zfs list output $(/bin/cat /tmp/zfs_list_err)" \
	| /bin/mail -s "ZFS list $store_server snapshots FAILED!" $email
	#delete error files
	/bin/rm -f /tmp/ssh_std_err /tmp/zfs_list_err /tmp/store_snaps /tmp/back_snaps
	exit 1
fi

if [ ! -z $common_snap ]; then
	#this sends the incrementals of all snapshots created since the last snapshot send to the backup server
	#ouput of the zfs send and zfs receive commands is saved in temporary txt files to be sent to user
	#save the exit status of the two sides of pipe in variables and add them for a exit status total`
	/bin/ssh -i $ssh_backup_key $store_server /sbin/zfs send -vI $store_pool_name/$common_snap $store_pool_name/$latest_snap 2> /tmp/zfs_send_tmp.txt\
	| /sbin/zfs receive -vF $backup_pool_name/$store_backup_fileshare &> /tmp/zfs_receive_tmp.txt;\
	pipe1=${PIPESTATUS[0]} pipe2=${PIPESTATUS[1]} 
	total_err=$(($pipe1+$pipe2))
	#tests if zfs send worked successfully, if not send email with exit statuses
	if [ $total_err -eq 0 ]; then
		#MAIL="ZFS send backup SUCCEEDED! \n"
		#printf "$MAIL \n Send output:\n $( cat /tmp/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat /tmp/zfs_receive_tmp.txt)" | mail -s "ZFS send backup SUCCEEDED!" $email
		/bin/rm -f /tmp/zfs_receive_tmp.txt /tmp/zfs_send_tmp.txt
		exit 0
   else
        MAIL="ZFS send backup FAILED! Error:"
        /bin/printf "$MAIL \n pipe: $pipe1\n pipe2: $pipe2\n\n Send output:\n $( /bin/cat /tmp/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat /tmp/zfs_receive_tmp.txt)" | /bin/mail -s "ZFS send backup FAILED!" $email
        /bin/rm -f /tmp/zfs_receive_tmp.txt /tmp/zfs_send_tmp.txt
		exit 2
   fi
else
    MAIL="ZFS send backup FAILED due to no common snapshot! \n This is bad, with no common snapshots you cannot send incremental snapshots. \n Last backed up snapshot $backup_pool_name/$(tail -n 1 /tmp/back_snaps)\n Oldest storage snapshot $store_pool_name/$(tail -n 1 /tmp/store_snaps)"
    /bin/printf "$MAIL \n " | /bin/mail -s "ZFS send backup FAILED with no common snapshots!" $email
	/bin/rm -f /tmp/store_snaps /tmp/back_snaps
	exit 3
fi