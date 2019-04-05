# Check pfSense
Nagios/Icinga script to check pfsense devices

# Usage:
```
   -H   Hostname to query - (required)
   -C   SNMP read community (default=public)
   -t   Specify the check (required)
          cpu - Checks the cpu usage
          disk - Checks the cpu usage
          diskusage [-d disnbr] - Checks the cpu usage
          load - Checks the cpu usage
          memory - Checks the cpu usage
          procs - Checks the cpu usage
          states - Checks the cpu usage
          users - Checks the cpu usage
   -w   Warning threshold
          Default depends of query
   -c   Critical threshold
          Default depends of query
   -h   Usage help 
```

# Examples:

Check Memory/Swap Usage
```
./check_pfSense.sh -H 192.168.1.1 -C public -t memory -w 80,30 -c 90,50
OK Memory usage: 63% - Total: 7.973M, used: 4.1022M, free: 2.974M
```
Check CPU Usage
```
./check_pfSense.sh -H 192.168.1.1 -C public -t cpu
OK 3% cpu used - 50/75
```
Check Load Average
```
./check_pfSense.sh -H 192.168.1.1 -C public -t load -w 2 -c 4
OK load = 0.15, 0.41, 0.86
```
