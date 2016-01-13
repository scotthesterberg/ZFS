# Whats here?
This is a pile of scripts I have created to manage my ZFS file server. They are designed to work with [zfssnap](https://github.com/zfsnap/zfsnap).

# Descriptions
	*zfs_backup.sh : Execute on backup server to pull snapshots off production zfs file servers. Both should have zfsnap installed, the backup server will need key based access to the production server.
	
	*zfs_scrub.sh : Scrub all pools on server with this script, schedule with cron.
	
	*zfs_compress_ratio.sh : Quick and dirty show details for all filesystems on all pools related to space utilization.
	
	*zfs_destroy_expired_backup_snaps.sh : Destroys all snapshots on backup ZFS server that have outlived their zfsnap defined TTL from a specific production server.
	
	*zfs_destory_backed_up_snaps.sh : This script is run from your backup ZFS and places hold on a defined number (default 2) of common snapshots between the backup server and source ZFS server, additionally adds holds to snapshots not yet backed up. This prevents deletion of common snap shots between the two which are required for incremental backups. It also removed old holds and deletes snapshots on source that have exceeded a defined TTL (default 3).
	
	*zfs_destroy_storage_snaps.sh : This script was to run on source/production ZFS box to delete zfsnap snapshots that had excceded a defined TTL. Much simpler than zfs_destory_backed_up_snaps.sh the disadvantage to using this was that snaps were blindly deleted whether or not they had been backed up which can put you in a situation with no common snapshots between your backup server and source.
	
	*ZFS on CentOS.txt : Basic documentation on how I have been able to set up a ZFS on CentOS file server. One thing to note is yum update after you have installed ZFS frequently breaks the loading of the ZFS kernel modules, so be careful updating your box, you can always go back a kernel version to fix things, but it can be a real pain.

