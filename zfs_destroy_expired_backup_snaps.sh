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


#this script deletes expired zfsnap snapshots from the system it is run on according to their ttl

#pull sensitive variables for this script from variable definition file
if [ -f ~/variables.txt ]; then
	source ~/variables.txt
else
	MAIL="Variables definition file missing! As a result ZFS snapshot deletion could not be run on $(hostname)"
	printf "$MAIL" | mail -s "ZFS snapshot deletion failed!" $email
	exit 1
fi

#delete expired snapshots on zfs server

#backup_pool_name=nameofbackuppool
#store_fileshare_name=nameoffileshare
hosts=$store_server_hostname
deleted=""

for hostname in $hosts
do
	for snapType in hourly- daily- weekly- monthly- yearly-
	do
		deleted="$deleted\n $(/usr/local/sbin/zfsnap destroy -r -p $hostname-$snapType $backup_pool_name/$store_fileshare_name 2> /dev/null)"
	done
done
#email user snapshots that were deleted, it any where
#comment out to stop constant emails
#if [ -z $deleted ]; then
	#MAIL="ZFS snapshots on $(hostname) deleted! \n"
	#printf "$MAIL \n $deleted" | mail -s "ZFS snapshots on $(/bin/hostname -s) deleted!" $email
	#exit 0
#fi