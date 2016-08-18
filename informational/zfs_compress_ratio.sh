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

pools=$(/sbin/zpool list -H -o name)
for pool in $pools; do
	for filesystem in $(/sbin/zfs list -H | cut -f1 | sed -e "s/$pool\///g" -e "/$pool/d")
	do
		/sbin/zfs get compressratio $pool/$filesystem
		/sbin/zfs get -H used $pool/$filesystem
		/sbin/zfs get -H logicalused $pool/$filesystem
		/sbin/zfs get -H usedbysnapshots $pool/$filesystem
		/sbin/zfs get -H usedbydataset $pool/$filesystem
		echo
	done
done
/sbin/zpool list
