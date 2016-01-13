#!/bin/bash

INTERVAL="$1"

if [ -z $INTERVAL ]
then
    INTERVAL=5
fi

OLDHITS=0
OLDMISS=0
L2OLDHITS=0
L2OLDMISS=0

i=0

while true
do

    RAW=`cat /proc/spl/kstat/zfs/arcstats`
    HITS=`echo "$RAW"  | grep -w hits | awk '{ print $3}'`
    L2HITS=`echo "$RAW"  | grep -w l2_hits | awk '{ print $3}'`
    MISSES=`echo "$RAW"  | grep -w misses | awk '{ print $3}'`
    L2MISSES=`echo "$RAW"  | grep -w l2_misses | awk '{ print $3}'`


    HITRATE=$(((HITS-OLDHITS)/INTERVAL))
    L2HITRATE=$(((L2HITS-L2OLDHITS)/INTERVAL))
    MISSRATE=$(((MISSES-OLDMISS)/INTERVAL))
    L2MISSRATE=$(((L2MISSES-L2OLDMISS)/INTERVAL))

    OLDHITS=$HITS
    L2OLDHITS=$L2HITS
    OLDMISS=$MISSES
    L2OLDMISS=$L2MISSES

    REQS=$((HITRATE+MISSRATE))
    
    if [ "$HITRATE" != 0 ] && [ "$REQS" != 0 ]
    then
        HITPERCENT=`echo "scale=2; (($HITRATE / $REQS) * 100)" | bc`
        L2HITPERCENT=`echo "scale=2; (($L2HITRATE / $REQS) * 100)" | bc`
    else
        HITPERCENT=0
        L2HITPERCENT=0
    fi

    if [ "$i" -gt 0 ]
    then 
        echo "IOPs: $REQS | ARC cache hit ratio: $HITPERCENT % | Hitrate: $HITRATE / Missrate: $MISSRATE | L2ARC $L2HITPERCENT $L2HITRATE / $L2MISSRATE"
    else
        echo "..."
    fi

    ((i++))
    sleep $INTERVAL
done
