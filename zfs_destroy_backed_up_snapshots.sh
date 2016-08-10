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


#this script deletes expired snapshots that have been backed up on zfs using zfsnap
#it is designed to work from a backup system which deletes snapshots on the source system
#while maintaing a set number of common snapshots, which are required for incremental sends
#the snapshots are only deleted if they have been backed up succesfully and the exceed the snapshot life ttl
#this is ensured by placing a zfs hold on the snapshots that have not been backed up
#additionally holds are placed on common backed up snapshots

#pull sensitive variables for this script from variable definition file
if [ -f ~/variables.txt ]; then
	source ~/variables.txt
else
	MAIL="Variables definition file missing! As a result ZFS snapshot deletion could not be run $(hosname)"
	printf "$MAIL" | mail -s "ZFS snapshot deletion failed!" $email
	exit 1
fi

deleted=""
#zfsnap ttl for snapshots, h=hours, d=days, m=months
snap_life=3d
#tag for zfs holds
hold_tag=protected_snap
num_common_snaps=2
new_holds=""
#email=youremailaddress
#backup_pool_name=localpoolname
#store_pool_name=remotepoolname
#store_fileshare_name=nameofremotefilesshare
#store_server=remoteserverip


#store list of snapshots on backup server
/sbin/zfs list -Hr -t snap $backup_pool_name/$store_fileshare_name | /bin/awk '{print $1}' | awk -F / '{print $2}' > /tmp/back_snaps

#store list of snapshots on storage server
/bin/ssh -i ~/.ssh/id_rsa_backup $store_server /sbin/zfs list -Hr -t snap $store_pool_name/$store_fileshare_name 2> ~/ssh_std_err | /bin/awk '{print $1}' | awk -F / '{print $2}' > /tmp/store_snaps

last_back_snap="${back_snaps[1]}"

#test to see if we were successful in listing snapshots
if [[ ! -s /tmp/ssh_std_err && ! -s /tmp/zfs_list_err ]]; then
	#delete error files
	/bin/rm -f /tmp/ssh_std_err /tmp/zfs_list_err 2> /dev/null
	
	#find common snapshot on backup and storage servers
	/bin/grep -F -x -f /tmp/back_snaps /tmp/store_snaps > /tmp/common_snaps
	
	#sort snapshots from previous command by date and add latest common snap to common_snap variable
	grep "$(/bin/cat /tmp/common_snaps | /bin/cut -d "-" -f4-6 | /bin/sort | /bin/tail -n $num_common_snaps)" /tmp/common_snaps > /tmp/common
	mv -f /tmp/common /tmp/common_snaps
	
	#determine last common snapshot
	last_common=$(/bin/tail -n 1 /tmp/common_snaps)
	
	#create list of uncommon snapshots that happened after the last common snapshot, excepting hourlys
	/bin/sed -e "0,/$last_common/d" -e "/hourly/d" /tmp/store_snaps > /tmp/uncommon_snaps
	
	#create list of local snapshots with holds
	/sbin/zfs list -H -r -d 1 -t snapshot -o name $backup_pool_name/$store_fileshare_name | xargs -n1 zfs holds -H | grep $hold_tag | awk '{print $1}' | awk -F / '{print $2}' > /tmp/local_snap_holds
	esc=$?
	
	#create list of remote snapshots with holds
	/bin/ssh -i ~/.ssh/id_rsa_backup $store_server "/sbin/zfs list -H -r -d 1 -t snapshot -o name $store_pool_name/$store_fileshare_name | xargs -n1 zfs holds -H "| grep $hold_tag | awk '{print $1}' | awk -F / '{print $2}' > /tmp/remote_snap_holds
	esc=$(expr $esc + $?)
	
	#create list of common snapshots that do not already have holds on them
	#this grep means output anything that is in file2 that is not in file1
	common_snaps_remote=$(grep -F -x -v -f /tmp/remote_snap_holds /tmp/common_snaps)
	#create list of snapshots that have come into existance since the most recent common snap
	#that do not have holds on them, we will place holds on these, excepting hourly, 
	#to prevent their deletion before they have been backed up
	uncommon_snaps=$(grep -F -x -v -f /tmp/remote_snap_holds /tmp/uncommon_snaps)
	if [[ ! -z $common_snaps_remote && ! -z $uncommon_snaps ]]; then
		#add holds to snaps that are common, or that have been created after the last common snap on remote server
		/bin/ssh -i ~/.ssh/id_rsa_backup $store_server "for snap in "$common_snaps_remote" "$uncommon_snaps"; do /sbin/zfs hold $hold_tag '$store_pool_name/'\$snap; done"
		esc=$(expr $esc + $?)
	fi
	
	#add holds to snaps that are common on local server
	common_snaps_local=$(grep -F -x -v -f /tmp/local_snap_holds /tmp/common_snaps)
	if [[ ! -z $common_snaps_local ]]; then
		for snap in $common_snaps_local; do /sbin/zfs hold $hold_tag $backup_pool_name/$snap; done
		esc=$(expr $esc + $?)
	fi
	
	#create list of remote snaps that are not common and have holds on them
	grep -F -x -v -f /tmp/common_snaps /tmp/remote_snap_holds > /tmp/release_snap_holds
	release_snap_holds_remote=$(grep -F -x -v -f /tmp/uncommon_snaps /tmp/release_snap_holds)
	if [[ ! -z $release_snap_holds_remote ]]; then
		#release holds on remote snaps that are not common
		/bin/ssh -i ~/.ssh/id_rsa_backup $store_server "for snap in "$release_snap_holds_remote"; do /sbin/zfs release $hold_tag '$store_pool_name/'\$snap; done"
		esc=$(expr $esc + $?)
	fi
	
	#create list of local snaps that are not common and have holds
	release_snap_holds_local=$(grep -F -x -v -f /tmp/common_snaps /tmp/local_snap_holds)
	if [[ ! -z $release_snap_holds_local ]]; then
		#remove holds on snapshots that are not common
		for snap in $release_snap_holds_local; do /sbin/zfs release $hold_tag $backup_pool_name/$snap; done 
		esc=$(expr $esc + $?)
	fi
	
	#delete all the tmp files we created manipulating snapshot holds
	rm -f /tmp/back_snaps /tmp/common /tmp/common_snaps /tmp/local_snap_holds /tmp/remote_snap_holds /tmp/release_snap_holds /tmp/store_snaps /tmp/uncommon_snaps 2> /dev/null
	
	#check to see if our manipulation of snap holds went well
	if [ $esc = 0 ]; then
		#delete old snapshots on storage server
		deleted_remote="$deleted_remote \n$(ssh -i ~/.ssh/id_rsa_backup $store_server "for snapType in hourly- daily- weekly- monthly- yearly-; do /usr/local/sbin/zfsnap destroy -v -r -p \$(/bin/hostname -s)-\$snapType -F $snap_life $store_pool_name/$store_fileshare_name ; done")"
		#delete old snapshots from storage server on backup server
		for snapType in hourly- daily- weekly- monthly- yearly-
		do
			deleted_local="$deleted_local\n $(/usr/local/sbin/zfsnap destroy -r -p $hostname-$snapType $backup_pool_name/$store_fileshare_name 2> /dev/null)"
		done
		#send email
		MAIL="ZFS snapshots on $(/bin/hostname) and $store_server_hostname deleted! \n"
		printf "$MAIL \n$store_server_hostname \n$deleted_remote \n$(/bin/hostname -s) \n$deleted_local" | mail -s "ZFS snapshots on $(/bin/hostname -s) deleted!" $email
		exit 0
	#send email with exit code sum for holds if greater than 0
	else
		MAIL="ZFS holds on $store_server snapshots FAILED! Did not delete snapshots. Exit code:"
		printf "$MAIL \n$esc" | mail -s "ZFS destroy $store_server snapshots FAILED!" $email
		rm -f ~/ssh_std_err
		exit 1
	fi
else
	MAIL="ZFS list $store_server snapshots FAILED while attempting to destroy old snapshots! Error:"
	/bin/printf "$MAIL \nssh output: \n$( /bin/cat /tmp/ssh_std_err) \n\
	zfs list output $(/bin/cat /tmp/zfs_list_err)" \
	| /bin/mail -s "ZFS destroy $store_server snapshots FAILED\!" $email
	#delete error files
	/bin/rm -f /tmp/ssh_std_err /tmp/zfs_list_err /tmp/store_snaps /tmp/back_snaps
	exit 1
fi