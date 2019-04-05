#!/bin/sh

#Initial File: https://gitlab.unetresgrossebite.com/DevOps/puppet/blob/30bf4d18dd98d5dc1b658be56a312051f61ac9bc/modules/nagios/files/custom_plugins/check_pfsense
#rewritten by Pit Wenkin
#using stuff from: https://github.com/diogouchoas/check_pfsense/blob/master/check_pfsense.sh
#Additions include:
# - CPU check
# - Load check
# - Memory check
# - Disk check (diskusage was confusing)
# - Possibility to define custom warning/critical levels

Prg=`basename $0`
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3
ret=UNKNOWN
community="public"
target="127.0.0.1"
query="firmware"
port=1

      OID_MOUNTPOINT=".1.3.6.1.2.1.25.2.3.1.3"
       OID_FSBLKSIZE=".1.3.6.1.2.1.25.2.3.1.4"
     OID_FSBLKAMOUNT=".1.3.6.1.2.1.25.2.3.1.5"
       OID_FSBLKUSED=".1.3.6.1.2.1.25.2.3.1.6"
	   OID_PROCS=".1.3.6.1.2.1.25.1.6.0"
	   OID_USERS=".1.3.6.1.2.1.25.1.5.0"
	  OID_STATES=".1.3.6.1.4.1.12325.1.200.1.3.1.0"
	     OID_CPU=".1.3.6.1.4.1.2021.11.11.0"
	    OID_LOAD=".1.3.6.1.4.1.2021.10.1.3.1"
	   OID_LOAD5=".1.3.6.1.4.1.2021.10.1.3.2"
	  OID_LOAD15=".1.3.6.1.4.1.2021.10.1.3.3"
	    OID_MEMT=".1.3.6.1.4.1.2021.4.5.0"
	    OID_MEMF=".1.3.6.1.4.1.2021.4.11.0"
       OID_DISK_UPCT=".1.3.6.1.4.1.2021.9.1.9.1"
	OID_DISK_TOT=".1.3.6.1.4.1.2021.9.1.6.1"
       OID_DISK_FREE=".1.3.6.1.4.1.2021.9.1.7.1"

usage()
{
    echo "Usage: $Prg -H host -C community -t query -w warning -c critical"
    echo "  query: cpu"
    echo "  query: disk"
    echo "  query: diskusage [-d disknbr]"
    echo "  query: load"
    echo "  query: memory"
    echo "  query: procs"
    echo "  query: states"
    echo "  query: users"
}

if test -z "$1"; then
    usage
    exit $UNKNOWN
fi

while getopts H:C:t:d:w:c:h OPT
do
    case $OPT in
	H) target=$OPTARG	;;
	C) community=$OPTARG	;;
	t) query=$OPTARG	;;
	d) disk=$OPTARG		;;
	w) warning=$OPTARG	;;
	c) critical=$OPTARG	;;
	h)
	    usage
	    exit $UNKNOWN
	    ;;
    esac
done

if test $query = diskusage; then
    for i in `seq 1 100`
    do
	test "$disk" && i=$disk
	mpt=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_MOUNTPOINT.$i | sed 's|"||g'`
	echo "$mpt" | grep UMA && break
	echo "$mpt" | grep MALLOC && break
	bsz=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_FSBLKSIZE.$i`
	tsz=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_FSBLKAMOUNT.$i`
	usz=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_FSBLKUSED.$i`
	tsz=`expr $tsz '*' $bsz`
	usz=`expr $usz '*' $bsz`
	free=`expr $tsz - $usz`
	if echo "$mpt" | grep '^/,'; then
	    if test `expr $free '*' 20` -lt $tsz; then
		ret=CRITICAL
	    elif test `expr $free '*' 10` -lt $usz; then
		ret=WARNING
	    elif test $tsz -ge 0 -a $usz -ge 0; then
		ret=OK
	    fi
	fi
	for val in free usz tsz
	do
	    unit=b
	    eval i=\$$val
	    while :
	    do
		case $unit in
		    b)	unit=k	;;
		    k)	unit=M	;;
		    M)	unit=G	;;
		    G)	unit=T	;;
		    T)	unit=P	;;
		    P)	unit=E	;;
		    E)	unit=Z	;;
		    *)	break	;;
		esac
		if test `expr $i / 1024` -lt 1024; then
		    i="`expr $i / 1024`.`expr $i % 1024`"
		    break
		fi
		i=`expr $i / 1024`
	    done
	    eval $val=$i$unit
	done
	test "$msg" && msg="$msg,"
	msg="$msg $mpt usage: $free/$usz/$tsz (free/used/tot)"
	test "$disk" && break
    done
elif test $query = disk; then
    diskpct=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_DISK_UPCT`
    #disktot=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_DISK_TOT`
    diskfree=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_DISK_FREE`
    if test $diskpct -gt $critical; then
        ret=CRITICAL
    elif test $diskpct -gt $warning; then
        ret=WARNING
    elif test $diskpct -ge 0; then
        ret=OK
    fi
	for val in free diskfree
	do
	    unit=b
	    eval i=\$$val
	    while :
	    do
		case $unit in
		    b)	unit=k	;;
		    k)	unit=M	;;
		    M)	unit=G	;;
		    G)	unit=T	;;
		    T)	unit=P	;;
		    P)	unit=E	;;
		    E)	unit=Z	;;
		    *)	break	;;
		esac
		if test `expr $i / 1024` -lt 1024; then
		    i="`expr $i / 1024`.`expr $i % 1024`"
		    break
		fi
		i=`expr $i / 1024`
	    done
	    eval $val=$i$unit
	done
    msg=" free space: / $diskfree ($diskpct%)"
elif test $query = users; then
    res=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_USERS`
    warning=${warning:='5'}
    critical=${critical:='10'}
    if test $res -gt $critical; then
        ret=CRITICAL
    elif test $res -gt $warning; then
        ret=WARNING
    elif test $res -ge 0; then
        ret=OK
    fi
    msg=" $res active sessions"
elif test $query = cpu; then
    res=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_CPU`
    used=`expr 100 - $res`
    warning=${warning:='50'}
    critical=${critical:='75'}
    if test $used -gt $critical; then
        ret=CRITICAL
    elif test $used -gt $warning; then
        ret=WARNING
    elif test $used -ge 0; then
        ret=OK
    fi
    msg=" $used% cpu used - $warning/$critical"
elif test $query = load; then
    load=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_LOAD | sed 's|"||g'`
    load5=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_LOAD5 | sed 's|"||g'`
    load15=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_LOAD15 | sed 's|"||g'`

    load100=$(echo "scale=0; 100*$load" | bc)
    load105=$(echo "scale=0; 100*$load5" | bc)
    load115=$(echo "scale=0; 100*$load15" | bc)
    load100=$(echo $load100 |cut -d '.' -f 1)
    load105=$(echo $load105 |cut -d '.' -f 1)
    load115=$(echo $load115 |cut -d '.' -f 1)

    warning=${warning:='0.75'}
    critical=${critical:='1'}
    warning100=$(echo "scale=0; 100 * $warning" | bc)
    critical100=$(echo "scale=0; 100 * $critical" | bc)
    warning100=$(echo $warning100 |cut -d '.' -f 1)
    critical100=$(echo $critical100 |cut -d '.' -f 1)

    if test $load105 -gt $critical100; then
	if test $load115 -gt $critical100; then
		ret=CRITICAL
	else
		ret=WARNING
	fi
    elif test $load105 -gt $warning100; then
	if test $load115 -gt $warning100; then
		ret=CRITCAL
	else
		ret=WARNING
	fi
    else
        ret=OK
    fi
    msg=" load = $load, $load5, $load15"


elif test $query = memory; then
    memt=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_MEMT | sed 's|"||g'`
    memf=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_MEMF | sed 's|"||g'`
    memf_pct=$(echo "scale=0; $memf*100/$memt" | bc)
    memu=$(($memt-$memf))
    memu_pct=$((100-$memf_pct))

    warning=${warning:='70'}
    critical=${critical:='80'}
    warning=$(echo $warning |cut -d ',' -f 1)
    critical=$(echo $critical |cut -d ',' -f 1)

    if test $memu_pct -gt $critical; then
        ret=CRITICAL
    elif test $memu_pct -gt $warning; then
        ret=WARNING
    elif test $memu_pct -ge 0; then
        ret=OK
    fi
	for val in free memt memf memu
	do
	    unit=b
	    eval i=\$$val
	    while :
	    do
		case $unit in
		    b)	unit=k	;;
		    k)	unit=M	;;
		    M)	unit=G	;;
		    G)	unit=T	;;
		    T)	unit=P	;;
		    P)	unit=E	;;
		    E)	unit=Z	;;
		    *)	break	;;
		esac
		if test `expr $i / 1024` -lt 1024; then
		    i="`expr $i / 1024`.`expr $i % 1024`"
		    break
		fi
		i=`expr $i / 1024`
	    done
	    eval $val=$i$unit
	done
    msg=" Memory usage: $memu_pct% - Total: $memt, used: $memu, free: $memf"
elif test $query = procs; then
    res=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_PROCS`
    warning=${warning:='150'}
    critical=${critical:='200'}
    if test $res -gt $critical; then
	ret=CRITICAL
    elif test $res -gt $warning; then
	ret=WARNING
    elif test $res -ge 0; then
	ret=OK
    fi
    msg=" $res processes"
elif test $query = states; then
    res=`snmpget -t2 -r2 -v1 -c $community -Ovq $target $OID_STATES`
    warning=${warning:='15000'}
    critical=${critical:='20000'}
    if test $res -gt $critical; then
	ret=CRITICAL
    elif test $res -gt $warning; then
	ret=WARNING
    elif test $res -gt 0; then
	ret=OK
    fi
    msg=" $res states"
fi >/dev/null 2>&1

echo $ret$msg$pefdata
eval ret=\$$ret
exit $ret

