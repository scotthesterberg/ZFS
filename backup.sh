
ssh_key=~/.ssh/id_rsa
email=none@none
user=$USER

# FUNCTIONS
Help() {
    cat << EOF
${0##*/} v${VERSION}

Syntax:
${0##*/} destroy [ options ] zpool/filesystem ...

OPTIONS:
  -b           = source (to be backed up) zfs pool and filesystem, pool_name/filesystem_name
  -d           = destination (to store backup) zfs pool and filesystem, pool_name/filesystem_name
  -e		   = email address to send notification to
  -f 		   = remote zfs systems IP address or DNS name
  -h           = Print this help and exit
  -k 		   = ssh key to be used to authenticate to remote zfs system; default ~/.ssh/id_rsa
  -n           = Dry-run. Perform a trial run with no backup actually performed
  -R		   = source zfs system ssh's to destination instead of default destination zfs sytem ssh'ing to source
  -s           = Skip pools that are resilvering
  -S           = Skip pools that are scrubbing
  -u 		   = user for authentication via ssh to remote zfs system; default current user
  -v           = Verbose output

LINKS:
  website:          http://www.zfsnap.org
  repository:       https://github.com/zfsnap/zfsnap
  bug tracking:     https://github.com/zfsnap/zfsnap/issues

EOF
    Exit 0
}

# main loop; get options, process snapshot expiration/deletion
while [ -n "$1" ]; do
    OPTIND=1
    while getopts e:f:hk:l:nrRsSvz OPT; do
        case "$OPT" in
            b) echo "source $OPTARG";;
            d) echo "destination $OPTARG";;
            e) echo "email $OPTARG";;
            f) echo "remote ip $OPTARG";;
            h) Help;;
            k) echo "ssh key $OPTARG";;
            n) echo "dry run";;
            R) echo "reverse zfs send";;
            s) PopulateSkipPools 'resilver';;
            S) PopulateSkipPools 'scrub';;
            v) VERBOSE='true';;

            :) Fatal "Option -${OPTARG} requires an argument.";;
           \?) Fatal "Invalid option: -${OPTARG}.";;
        esac
    done

    # discard all arguments processed thus far
    shift $(($OPTIND - 1))

done
#check to see that required arguments have been provided
#if ! $fflag || ! $lflag || ! $rflag
#then
#    echo "-r, -f, -l must be included" >&2
#    exit 1
#fi




#execute zfs_backup functions to go into core

#source ~/variables.txt
#source ./zfs_backup.sh

#ListLocalSnapshots $backup_pool_name/$store_backup_fileshare

#echo "Local snapshots:"
#echo "${RETVAL[*]}"
#echo
#local_snaps="${RETVAL[*]}"

#ListRemoteSnapshots $ssh_backup_key $user $store_server $store_pool_name/$store_fileshare_name

#echo "Remote snapshots:"
#echo "${RETVAL[*]}"
#echo
#remote_snaps="${RETVAL[*]}"

#LatestRemoteSnap "${remote_snaps[*]}"

#echo "Latest remote snapshot:"
#echo "${RETVAL[*]}"
#echo
#latest_snap="${RETVAL[*]}"

#FindCommonSnapshot "${local_snaps[*]}" "${remote_snaps[*]}" 

#echo "Latest common snapshot:"
#echo "${RETVAL[*]}"
#echo
#common_snap="${RETVAL[*]}"

#SendSnapshots $ssh_backup_key $user $store_server $store_pool_name/$store_fileshare_name $backup_pool_name/$store_backup_fileshare $common_snap $latest_snap
