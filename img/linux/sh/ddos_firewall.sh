#!/bin/bash
#
#Athor:ChenYanshan  (E-mail:itcys@qq.com)
#Mon May  9 03:47:46 CST 2016

logFlie=/root/ddos_nginx_log/com_nginx.log
ip_logFile=/root/ddos_nginx_log/ip_`date +%y%m%d`.log
ddos_ipFile=/root/ddos_nginx_log/ddos_ip_`date +%y%m%d`.log

awk -F" " '/^[1-9]/ {sum[$1]++} END {for (ip in sum) {printf "%-40s %d\n", ip, sum[ip]}}' $log | sort -k2 -rn | head -n200 > $ip_logFile

for i in $(sed 's/..........$//g' $ip_logFile)
	do
	code=`awk '/^'$i'/ {sum[$11]} END {for (k in sum) {printf "%s", k}}' $log`
	[ $code == '"-"' ] && echo $i >> $ddos_ipFile
	done

for i in $(cat $ddos_ipFile)
	do
	iptables -t filter -A INPUT -s $i -p tcp --dport 80 -j DROP
	iptables iptables save
	done
