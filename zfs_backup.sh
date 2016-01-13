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
if [ -f ~/variables.txt ]; then
	source ~/variables.txt
else
	MAIL="Variables definition file missing! As a result ZFS backup could not be run"
	printf "$MAIL" | mail -s "ZFS backup failed!" $email
	exit 1
fi

#~/cron_scripts/zfs_destroy_storage_snaps.sh

#initialize variables
match=1
#email=youremail
#store_server=zfsfilestoreserverip/dns
#store_pool_name=storagezfsserverpoolname
#store_filesystem_name=storagezfsserverfilesystemname
#backup_pool_name=backupzfsserverpoolname
#backup_filesystem_name=backupezfsserverfilesystemname

#store list of snapshots on backup server
back_snaps=($(/sbin/zfs list -Hr -t snap $backup_pool_name/$store_fileshare_name | /bin/awk '{print $1}' | /bin/sort -r))

#store list of snapshots on storage server
store_snaps=($(/bin/ssh -i ~/.ssh/id_rsa_backup $store_server /sbin/zfs list -Hr -t snap $store_pool_name/$store_fileshare_name 2> ~/ssh_std_err | /bin/awk '{print $1}'))

latest_snap="${store_snaps[-1]}"

#test to see if we were successful in listing backup server snapshots
if [ "$(cat ~/ssh_std_err 2> /dev/null )" == "" ]; then
	#find common snapshot on backup and storage servers
	#first itterate through lines in back_snaps
	for back_snap in "${back_snaps[@]}"; do
		#itterate through lines in store_snaps
		for store_snap in "${store_snaps[@]}"; do 
			#compares current back_snap value to ever store_snap value
			if [ "$(/bin/echo $back_snap | /bin/awk -F / '{print $2}')" == "$( /bin/echo $store_snap | /bin/awk -F / '{print $2}')" ]; then 
				match=0
				break 2
			else 
				match=1
			fi
		done
	done
else
	MAIL="ZFS list $store_server snapshots FAILED! Error:"
	/bin/printf "$MAIL \n ssh output:\n $( /bin/cat ~/ssh_std_err) )" | /bin/mail -s "ZFS list $store_server snapshots FAILED!" $email
	/bin/rm -f ~/ssh_std_err
	exit 1
fi

if [ "$match" -eq "0" ]; then
	#this sends the incrementals of all snapshots created since the last snapshot send to the backup server
	#ouput of the zfs send and zfs receive commands is saved in temporary txt files to be sent to user
	#save the exit status of the two sides of pipe in variables and add them for a exit status total`
	/bin/ssh -i ~/.ssh/id_rsa_backup $store_server /sbin/zfs send -vI $store_snap $latest_snap 2> ~/zfs_send_tmp.txt\
	| /sbin/zfs receive -vF backup/x &> ~/zfs_receive_tmp.txt;\
	pipe1=${PIPESTATUS[0]} pipe2=${PIPESTATUS[1]} 
	total_err=$(($pipe1+$pipe2))
	#tests if zfs send worked successfully, if not send email with exit statuses
	if [ $total_err -eq 0 ]; then
		#MAIL="ZFS send backup SUCCEEDED! \n"
		#printf "$MAIL \n Send output:\n $( cat ~/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat ~/zfs_receive_tmp.txt)" | mail -s "ZFS send backup SUCCEEDED!" $email
		/bin/rm -f ~/zfs_receive_tmp.txt ~/zfs_send_tmp.txt
		exit 0
   else
        MAIL="ZFS send backup FAILED! Error:"
        /bin/printf "$MAIL \n pipe: $pipe1\n pipe2: $pipe2\n\n Send output:\n $( /bin/cat ~/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat ~/zfs_receive_tmp.txt)" | /bin/mail -s "ZFS send backup FAILED!" $email
        /bin/rm -f ~/zfs_receive_tmp.txt ~/zfs_send_tmp.txt
		exit 2
   fi
else
    MAIL="ZFS send backup FAILED due to no common snapshot! \n This is bad, with no common snapshots you cannot send incremental snapshots. \n Last backed up snapshot ${back_snaps[1]}  \n Oldest storage snapshot ${store_snaps[1]}"
    /bin/printf "$MAIL \n " | /bin/mail -s "ZFS send backup FAILED with no common snapshots!" $email
	exit 3
fi