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

#variables required
#email=youremail
#store_server=zfsfilestoreserverip/dns
#store_pool_name=storagezfsserverpoolname
#store_filesystem_name=storagezfsserverfilesystemname
#backup_pool_name=backupzfsserverpoolname
#backup_filesystem_name=backupezfsserverfilesystemname

#pull sensitive variables for this script from variable definition file
#if [ -f ~/variables.txt ]; then
#	source ~/variables.txt
#else
#	#MAIL="Variables definition file missing! As a result ZFS backup could not be run"
#	#printf "$MAIL" | mail -s "ZFS backup failed!" $email
#	Mail 'ZFS backup failed!' "Variables definition file missing! As a result ZFS backup could not be run" 
#	exit 1
#fi

#function for sending email
Mail(){
	#first argument should be subject of email
	local subject=$1
	#second argument should be body of email
	local body=$2

	printf "$body" | mail -s "$subject" $email
}

#run old snapshot deletion script before running backups
#this may free up needed space
#./zfs_destroy_backed_up_snapshots.sh

#this function creates a list of the names of snapshots on the local zfs system
#with the names formatted so that only the portion after the @sign that makes up the standard zfs naming scheme is returned
ListLocalSnapshots(){
	#location of snapshots in format of "zfs_pool_name/zfs_filesystem_name"
	if [ -z $1 ]; then
		echo "Please provide location of snapshots in format of zfs_pool_name/zfs_filesystem_name"
		return 1
	else
		local snapshot_location=$1
	fi
	
	local local_snaps=$(/sbin/zfs list -Hr -t snap $snapshot_location 2> /tmp/zfs_list_err | /bin/awk '{print $1}' | /bin/awk -F @ '{print $2}')
	
	RETVAL=$local_snaps
	if [ -s /tmp/zfs_list_err ]; then
		echo "Recieved error from zfs list, perhaps $snapshot_location does not exist"
		echo -e "Error recieved: \n"
		cat /tmp/zfs_list_err
		return 1
	fi
}

#store list of snapshots on remote server
#/bin/ssh -i $ssh_backup_key $store_server "~/cron_scripts/zfs_destroy_storage_snaps.sh && /sbin/zfs list -Hr -t snap $store_pool_name/$store_fileshare_name " 2> /tmp/ssh_std_err | /bin/awk '{print $1}' | /bin/awk -F @ '{print $2}' > /tmp/store_snaps

#this function creates a list of the names of snapshots on a remote zfs system
#with the names formatted so that only the portion after the @sign that makes up the standard zfs naming scheme is returned
ListRemoteSnapshots(){
	#location of ssh key to used for authentication
	local ssh_key=$1
	#user to authenticate as
	local user=$2
	#ip or dns of remote server
	local remote_server=$3
	#location of snapshots in format of "zfs_pool_name/zfs_filesystem_name"
	local snapshot_location=$4
	
	#if we still want to delete zero byte snapshots before creating our list of remote snapshots we need to make something like the below work
	#~/cron_scripts/zfs_destroy_storage_snaps.sh
	#perhaps scp the shell script over to /tmp
	#/bin/scp -i $ssh_key ./zfs_destroy_storage_snaps.sh $remote_server:/tmp/
	#then run it and then clean up
	#/bin/ssh -i $ssh_key $remote_server "/usr/bin/chown +x /tmp/zfs_destroy_storage_snaps.sh && ./tmp/zfs_destroy_storage_snaps.sh && rm -f /tmp/zfs_destroy_storage_snaps.sh"
	
	local remote_snaps=$(/bin/ssh -i $ssh_key $user@$remote_server "/sbin/zfs list -Hr -t snap $snapshot_location " 2> /tmp/ssh_std_err | /bin/awk '{print $1}' | /bin/awk -F @ '{print $2}')
	
	RETVAL=$remote_snaps
}

LatestRemoteSnap(){
	local remote_snaps=("$@")
	
	#find latest storage server snapshot
	#to be sent with all predecessors created since last backup to backup server
	local latest_snap=$(echo "$remote_snaps" | grep $(echo ${remote_snaps[*]} | tr " " "\n" | /bin/cut -d "-" -f4-6 | /bin/sort | /bin/tail -n 1) | /bin/tail -n 1 tail -n 1)
	
	RETVAL=$latest_snap
}

FindCommonSnapshot(){
	local local_snaps=$1
	local remote_snaps=$2
	
	#test to see if we were successful in listing snapshots by checking that the error files don't exist and have a size greater than zero
	if [[ -z local_snaps && -z remote_snaps ]]; then
		#find common snapshot on remote and local servers
		local common_snaps=$(echo "${local_snaps[@]}" "${remote_snaps[@]}" | sort | uniq -d)
		if [[ -z common_snaps ]]; then
			echo "Failed to find common snapshot. This is bad as it means an incremental backup cannot be performed."
			echo "Please transfer a new common snapshot."
			return 2
		else
			#sort snapshots from previous command by date and add latest common snap to common_snap variable
			local common_snap=$(echo "${common_snaps[*]}" | grep $(echo ${common_snaps[*]} | tr " " "\n" | /bin/cut -d "-" -f4-6 | /bin/sort | /bin/tail -n 1) | /bin/tail -n 1)
			
			RETVAL=$common_snap
		fi
	else
		#Mail "ZFS list $store_server snapshots FAILED"'!' "ZFS list $store_server snapshots FAILED! Error: \n ssh output:\n $( /bin/cat /tmp/ssh_std_err) \n\ zfs list output $(/bin/cat /tmp/zfs_list_err)" 
		echo "Failed to find common snapshot because the list of common local snapshots or remote snapshots was empty."
		echo -e "Local snapshots: \n" "$local_snaps"
		echo -e "Remote snapshots: \n" "$remote_snaps"
		return 1
	fi
}

SendSnapshots(){
	if [ ! -z $common_snap ]; then
		#this sends the incrementals of all snapshots created since the last snapshot send to the backup server
		#ouput of the zfs send and zfs receive commands is saved in temporary txt files to be sent to user
		#save the exit status of the two sides of pipe in variables and add them for a exit status total
		/bin/ssh -i $ssh_backup_key $store_server /sbin/zfs send -vI $store_pool_name/$store_fileshare_name@$common_snap $store_pool_name/$store_fileshare_name@$latest_snap 2> /tmp/zfs_send_tmp.txt\
		| /sbin/zfs receive -vF $backup_pool_name/$store_backup_fileshare &> /tmp/zfs_receive_tmp.txt;\
		pipe1=${PIPESTATUS[0]} pipe2=${PIPESTATUS[1]} 
		total_err=$(($pipe1+$pipe2))
		#tests if zfs send worked successfully, if not send email with exit statuses
		if [ $total_err -eq 0 ]; then
			#MAIL="ZFS send backup SUCCEEDED! \n"
			#printf "$MAIL \n Send output:\n $( cat /tmp/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat /tmp/zfs_receive_tmp.txt)" | mail -s "ZFS send backup SUCCEEDED!" $email
			
			Mail "ZFS send backup SUCCEEDED"'!' "ZFS send backup SUCCEEDED! \n \n Send output:\n $( cat /tmp/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat /tmp/zfs_receive_tmp.txt)"
			
			/bin/rm -f /tmp/zfs_receive_tmp.txt /tmp/zfs_send_tmp.txt
			return 0
	   else
			#MAIL="ZFS send backup FAILED! Error:"
			#/bin/printf "$MAIL \n pipe: $pipe1\n pipe2: $pipe2\n\n Send output:\n $( /bin/cat /tmp/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat /tmp/zfs_receive_tmp.txt)" | /bin/mail -s "ZFS send backup FAILED!" $email
			
			Mail "ZFS send backup FAILED"'!' "ZFS send backup FAILED! Error: \n pipe: $pipe1\n pipe2: $pipe2\n\n Send output:\n $( /bin/cat /tmp/zfs_send_tmp.txt) \n\n\n Receive output:\n $(cat /tmp/zfs_receive_tmp.txt)"
			
			/bin/rm -f /tmp/zfs_receive_tmp.txt /tmp/zfs_send_tmp.txt
			return 2
	   fi
	else
		#MAIL="ZFS send backup FAILED due to no common snapshot! \n This is bad, with no common snapshots you cannot send incremental snapshots. \n Last backed up snapshot $backup_pool_name/$(tail -n 1 /tmp/back_snaps)\n Oldest storage snapshot $store_pool_name/$(tail -n 1 /tmp/store_snaps)"
		#/bin/printf "$MAIL \n " | /bin/mail -s "ZFS send backup FAILED with no common snapshots!" $email
		
		Mail "ZFS send backup FAILED with no common snapshots"'!' "ZFS send backup FAILED due to no common snapshot! \n This is bad, with no common snapshots you cannot send incremental snapshots. \n Last backed up snapshot $backup_pool_name/$(tail -n 1 /tmp/back_snaps)\n Oldest storage snapshot $store_pool_name/$(tail -n 1 /tmp/store_snaps)"
		
		/bin/rm -f /tmp/store_snaps /tmp/back_snaps
		return 3
	fi
}