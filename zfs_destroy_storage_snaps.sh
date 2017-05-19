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


#this script deletes 0 byte snapshots and expired snapshots on zfs using zfsnap

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
#email=youremailaddress
#filesystems=filesystemstosearchforsnapshots

#checks to see if filesystems have snopshots, and outputs the name(s) of filesystem(s) to variable fsWithSnapshots if they do
#the below commented out alternative variable definition can be used if you only want to look at snapshots with certain names
#fsWithSnapshots=$(/sbin/zfs list -Hr -t snapshot $filesystem | cut -d '@' -f 1 | uniq)
fsWithSnapshots=$(/sbin/zfs list -Hr -t snapshot | /bin/cut -d '@' -f 1 | /bin/uniq)

# For each of the above filesystems, delete empty snapshots
for fs in $fsWithSnapshots ; do
	#empty snapshots searched for and their names entered into emptySnapshot variable
	emptySnapshot=$(/sbin/zfs list -Hr -d1 -t snapshot -o name,used -s creation $fs | /bin/grep hourly | /bin/awk ' $2 == "0" { print $1 }' )
	for snapshot in $emptySnapshot ; do
		#echo "Destroying empty snapshot $snapshot"
		/sbin/zfs destroy $snapshot
	done
	#delete old snapshots from storage server
	#for snapType in hourly- daily- weekly- monthly- yearly- ; do
		#deleted="$deleted\n $(/usr/local/sbin/zfsnap destroy -r -p $(/bin/hostname -s)-$snapType -F $snap_life $fs)"
	#done
	#if [ -z $deleted ]; then
		#MAIL="ZFS snapshots on $(hostname) deleted! \n"
		#printf "$MAIL \n $deleted" | mail -s "ZFS snapshots on $(/bin/hostname -s) deleted!" $email
	#fi
done