

#OPTIONS:
#  -f 		   = remote zfs systems IP address or DNS name
#  -h           = Print this help and exit
#  -k 		   = ssh key to be used to authenticate to remote zfs system
#  -l           = local zfs pool and filesystem, pool_name/filesystem_name
#  -n           = Dry-run. Perform a trial run with no backup actually performed
#  -r           = remote zfs pool and filesystem, pool_name/filesystem_name
#  -R		   = push backup from local system to remote instead of pulling backup to local from remote
#  -s           = Skip pools that are resilvering
#  -S           = Skip pools that are scrubbing
#  -u 		   = user to use to authenticate via ssh to remote zfs system
#  -v           = Verbose output


#execute zfs_backup functions to go into core

source ~/variables.txt

ListLocalSnapshots $backup_pool_name/$store_backup_fileshare

echo "Local snapshots:"
echo "${RETVAL[*]}"
echo
local_snaps="${RETVAL[*]}"

ListRemoteSnapshots $ssh_backup_key $user $store_server $store_pool_name/$store_fileshare_name

echo "Remote snapshots:"
echo "${RETVAL[*]}"
echo
remote_snaps="${RETVAL[*]}"

LatestRemoteSnap "${remote_snaps[*]}"

echo "Latest remote snapshot:"
echo "${RETVAL[*]}"
echo

FindCommonSnapshot $local_snaps $remote_snaps 

echo "Latest common snapshot:"
echo "${RETVAL[*]}"
echo

#SendSnapshots $common_snap $latest_snap
