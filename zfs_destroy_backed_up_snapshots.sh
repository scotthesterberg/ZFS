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
common_snaps=2
new_holds=""
#email=youremailaddress
#filesystems=filesystemstosearchforsnapshots


#store list of snapshots on backup server
back_snaps=($(/sbin/zfs list -Hr -t snap $backup_pool_name/$store_fileshare_name | /bin/awk '{print $1}' | sort -r))

#store list of snapshots on storage server
store_snaps=($(/bin/ssh -i ~/.ssh/id_rsa_backup $store_server /sbin/zfs list -Hr -t snap $store_pool_name/$store_fileshare_name 2> ~/ssh_std_err | /bin/awk '{print $1}'))

last_back_snap="${back_snaps[1]}"

#test to see if we were successful in listing backup server snapshots
if [ "$(cat ~/ssh_std_err 2> /dev/null )" == "" ]; then
	#create list of snapshots with holds
	snap_holds=$(ssh -i ~/.ssh/id_rsa_backup $store_server "zfs list -H -r -d 1 -t snapshot -o name $store_pool_name/$store_fileshare_name | xargs -n1 zfs holds -H | grep $hold_tag | awk '{print \$1}'")
	
	#find common snapshot on backup and storage servers
	#first itterate through lines in back_snaps
	for back_snap in "${back_snaps[@]}"; do
		#itterate through lines in store_snaps
		for store_snap in "${store_snaps[@]}"; do 
			#compares current back_snap value to ever store_snap value
			if [ "$(echo $back_snap | awk -F / '{print $2}')" == "$( echo $store_snap | awk -F / '{print $2}')" ]; then 
				#test to see if this an hourly snapshot, we dont want to make them the basis of incrementals, so no holds for them
				#hourlys have short lives which is why they don't make a for good common holds
				#holds on hourlys could also prevent clearing out useless 0 byte hourly snaps
				if [ $( echo $store_snap | grep "hourly-" ) ]; then
					#we have a match but it is an hourly snapshot, not a good basis for a hold, skip to next common snap
					break 1
				else
					#start count of number of common snapshots
					((count+=1))
					#test if current count exceeds number of desired common snapshots
					if [ ! $count -le $common_snaps ]; then
						#release hold on snapshots that exceed the desired number of common snapshots
						ssh -i ~/.ssh/id_rsa_backup $store_server "/sbin/zfs release $hold_tag $store_snap 2> /dev/null"
					else
						#check if $store_snap already has a hold by comparing to list of snaps with holds in $snap_holds
						if [[ ! $snap_holds =~ $store_snap && ! $new_holds =~ $store_snap ]]; then
							#add hold to snapshot that is common between backup and source
							ssh -i ~/.ssh/id_rsa_backup $store_server "/sbin/zfs hold $hold_tag $store_snap"
							new_holds=$new_holds+"$store_snap "
							/sbin/zfs hold $hold_tag $back_snap
						fi
					fi
				fi
			else 
				#test to see if this an hourly snapshot, we dont want to make them the basis of incrementals, so no holds for them
				#hourlys have short lives which is why they don't make a for good common holds
				#holds on hourlys could also prevent clearing out useless 0 byte hourly snaps
				if [ ! $( echo $store_snap | grep "hourly-" ) ]; then
					#check if $store_snap already has a hold by comparing to list of snaps with holds in $snap_holds
					if [[ ! $snap_holds =~ $store_snap && ! $new_holds =~ $store_snap ]]; then
						#add hold to snapshot that is not common between backup and source
						ssh -i ~/.ssh/id_rsa_backup $store_server "/sbin/zfs hold $hold_tag $store_snap"
						new_holds=$new_holds+"$store_snap "
					fi
				fi
			fi
		done
	done
	#checks to see if filesystems have snapshots, and outputs the name(s) of filesystem(s) to variable fsWithSnapshots if they do
	#the below commented out alternative variable definition can be used if you only want to look at snapshots with certain names
	#fsWithSnapshots=$(/sbin/zfs list -Hr -t snapshot $filesystem | cut -d '@' -f 1 | uniq)
	fsWithSnapshots=$(ssh -i ~/.ssh/id_rsa_backup $store_server "/sbin/zfs list -Hr -t snapshot | cut -d '@' -f 1 | uniq")

	# For each of the above filesystems, delete empty snapshots
	for fs in $fsWithSnapshots ; do
		#delete old snapshots from storage server
		for snapType in hourly- daily- weekly- monthly- yearly- ; do
			deleted="$deleted\n $(ssh -i ~/.ssh/id_rsa_backup $store_server "/usr/local/sbin/zfsnap destroy -r -p $(/bin/hostname -s)-$snapType -F $snap_life $fs 2> /dev/null")"
		done
	done
	#if [ -z $deleted ]; then
		#MAIL="ZFS snapshots on $(hostname) deleted! \n"
		#printf "$MAIL \n $deleted" | mail -s "ZFS snapshots on $(/bin/hostname -s) deleted!" $email
		#exit 0
	#fi
else
	MAIL="ZFS list $store_server snapshots FAILED! Could not delete snapshots based on reservation of common snapshots. Error:"
	printf "$MAIL \n ssh output:\n $( cat ~/ssh_std_err) )" | mail -s "ZFS list $store_server snapshots FAILED!" $email
	rm -f ~/ssh_std_err
	exit 1
fi