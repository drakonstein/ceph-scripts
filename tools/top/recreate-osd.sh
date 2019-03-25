#! /bin/bash

INITSTATE=`ceph health`
FORCEMODE=0;
VERBOSE=0
BLUESTORE=0;

while [[ $# -gt 0 ]]
do
    key="$1"

    case "$key" in
        -f) 
        shift; 
        FORCEMODE=1;
        ;;

        -v)
        shift;
        VERBOSE=1;   
        ;; 

        --db)
        DBD=$2  
        shift;
        shift;
        ;;

        --osd)
        OSD=$2
        shift;
        shift;
        ;;

        --dev)
        DEV=$2
        shift;
        shift;
        ;;

        *)
        shift;
        ;;
    esac
done

function draw(){
    if [[ $VERBOSE -eq 1 ]];
    then 
        echo ${1}
    fi
}


if [[ -z $OSD ]];
then
    draw "no OSD provided, will autodetermine later on"
fi

draw "Checking ceph health"
draw $INITSTATE


if [[ `echo $INITSTATE | grep -q "HEALTH_OK"` -eq 1 ]]; 
then
    if [[ $FORCEMODE -eq 0 ]];
    then
        draw "Ceph is unhealthy, aborting"
        exit
    else
        draw "Ceph is unhealthy"
    fi
else
    draw "Ceph is healthy"
fi



if [[ -z $OSD ]];
then
    #autodetermine OSD
    AWKHOST=`echo $HOSTNAME | sed 's/.cern.ch//'`
    OSD=`ceph osd tree down | awk -v awkhost=$AWKHOST 'BEGIN { out=0 } { if($0 ~ /rack/) {out=0} if(out) {print $0; out=0} if($0 ~ awkhost) {out=1}; }' | grep -Eo "osd\.[0-9]+" | tr -d "[a-z\.]"`
fi

if [[ -z $DBD ]];
then 
  for i in `ceph-disk list | grep -E "ceph journal"  | grep -vE "for" | grep -oE "/dev/sd[a-z]+[0-9]"`;
  do 
    draw "investigating $i"
    lvs -o +devices,tags | grep -q $i; 
    if [[ $? -eq 1 ]];
    then 
      draw "$i can be used";
      DBD=$i;
    fi;
  done
  if [[ -z $DBD ]];
  then
    draw "No block device found, switching to ceph-volume"
    DBD=`ceph-volume lvm list | awk -v awkosdid=osd.$OSD 'BEGIN { out=0 } { if($0 ~ /====/) {out=0} if(out) {print $0;} if($0 ~ awkosdid) {out=1}; }'  | grep -Eo "db device.*$" | sed 's/db device.*\/dev\///';`
  fi
fi

echo "ceph-volume lvm zap $DEV"
echo "ceph-volume lvm zap /dev/$DBD"
echo "ceph osd destroy $OSD --yes-i-really-mean-it"
echo "ceph-volume lvm create --osd-id $OSD --data $DEV --block.db $DBD"




## TODO
#
# Auto discover osd to be replaced (grep on ceph osd tree down to find down osd on the host)
# Auto find if 2-disk OSDs are used

 
#  awk 'BEGIN { out=0 } { if($0 ~ /rack/) {out=0} if(out) {print $0} if($0 ~ /RJ55/) {out=1}; } '
