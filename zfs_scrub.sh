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
	MAIL="Variables definition file missing! As a result ZFS scrub could not be run"
	printf "$MAIL" | mail -s "ZFS scrub failed!" $email
	exit 1
fi

pools=$(/sbin/zpool list -H -o name)

for pool in $pools
do
	if [ $(/sbin/zpool status $pool | egrep -c "scrub in progress|resilver")=0 ]; then
			if [ $(/sbin/zpool scrub $pool)=0 ]; then
					sleep 3000
					MAIL="ZFS scrub ran. Output: \n\n $(/sbin/zpool status)"
					echo -e "$MAIL" | mail -s "ZFS scrub ran on '/bin/hostname -s'" $email
			else
					MAIL="ZFS scrub FAILED to run! Output: \n\n $(/sbin/zpool status)"
					echo -e "$MAIL" | mail -s "ZFS scrub FAILED to run on '/bin/hostname -s'" $email
			fi
	else
			MAIL="ZFS scrub FAILED to run due to ongoing scrub or disk resilver! Output: \n\n $(/sbin/zpool status)"
			echo -e "$MAIL" | mail -s "ZFS scrub FAILED to run  on '/bin/hostname -s' due to ongoing scrub or disk resilver" $email
	fi
done