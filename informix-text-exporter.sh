#!/bin/bash

if [ $# -ne 1 ]
then
	echo "
Usage: $0 frequency

Frequency is an integer number showing the number of times per hour to execute a query or queries.
Valid values are: 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30 and 60. Any other value will be ignored.
"
	exit 1
fi

frq=$1

starttime=$( date +%s )

case $frq in
	1|2|3|4|5|6|10|12|15|20|30|60)
		:
			;;
	*)
		echo "Invalid frequency: $frq"
		rm "${frq}.lock" 2> /dev/null
		exit 2
			;;
esac

textfile_path=$( jq '.[] | .textfile_path' < config.json 2> /dev/null | tr -d \" )

nummetrics=$( jq '. | length' < metrics.json 2> /dev/null )
cnt=0

ls -l static_labels > /dev/null 2>&1
sl_exists=$?

if [ $sl_exists -eq 0 ]
then
	statics=$( cat static_labels )
fi

cat /dev/null > "/tmp/informix-text-exporter.$frq.$$"

while [ "$cnt" -lt "$nummetrics" ]
do
	commas=0
	frequency=$( jq --argjson cnt "$cnt" '.[$cnt] | .frequency' < metrics.json 2> /dev/null | tr -d \" )

	if [ "$frequency" -eq "$frq" ]
	then

		metricname=$( jq --argjson cnt "$cnt" '.[$cnt] | .metricname' < metrics.json 2> /dev/null | tr -d \" )
		help=$( jq --argjson cnt "$cnt" '.[$cnt] | .help' < metrics.json 2> /dev/null | tr -d \" )
		type=$( jq --argjson cnt "$cnt" '.[$cnt] | .type' < metrics.json 2> /dev/null | tr -d \" )
		database=$( jq --argjson cnt "$cnt" '.[$cnt] | .database' < metrics.json 2> /dev/null | tr -d \" )
		sql=$( jq --argjson cnt "$cnt" '.[$cnt] | .sql' < metrics.json 2> /dev/null | tr -d \" )

		echo "# HELP $metricname $help" >> "/tmp/informix-text-exporter.$frq.$$"
		echo "# TYPE $metricname $type" >> "/tmp/informix-text-exporter.$frq.$$"

		origsql=$sql
		newsql=$sql
		subsel=1

		sql=""

		for i in $newsql
		do
			j=$( echo "$i" | tr "[:upper:]" "[:lower:]" )
			sql="$sql $j"
			if [ "x$j" == "xunion" ]
			then
				break
			fi
			if [ "x${j}" == "x(SELECT" ]
			then
				subsel=0
			fi
			if [ "x$j" == "xfrom" ]
			then
			        if [ $subsel -ne 0 ]
				then
					commas=$( echo "$sql" | while read -r x; do echo "$x" | grep -o "," | wc -l; done )
					if [ $(( commas % 2 )) -ne 0 ]
					then
						echo "WARNING: label without value or vice-versa"
					fi
				else
					subsel=1
				fi
		fi
		done

		sql=$origsql

		dbaccess "$database" <<! 2> /dev/null | grep -v "^$"
UNLOAD TO /tmp/informix-text-exporter.tmp.$frq.$$
$sql
!
		# if [ $( wc -l /tmp/informix-text-exporter.tmp.$frq.$$ | awk '{print $1}'  ) -eq 0 ]
		if [ -s /tmp/informix-text-exporter.tmp.$frq.$$ ]
		then
			# echo "OK: $sql"
			:
		else
			echo "Failed: $sql"
			cnt=$(( cnt + 1 ))
			continue
		fi
		sed -i -e "s/|$//" "/tmp/informix-text-exporter.tmp.$frq.$$"
		if [ "$commas" -ne 0 ]
		then
			sed -i -e "s/|/\"} /$commas" "/tmp/informix-text-exporter.tmp.$frq.$$"
		fi
		pipecnt=$( head -1 "/tmp/informix-text-exporter.tmp.$frq.$$" | grep -o "|" | wc -l | awk '{print $1}' )
		for ((k=1;k<=pipecnt;k++))
		do
			if [ $(( k % 2 )) -eq 1 ]
			then
				sed -i -e "s/|/=/" "/tmp/informix-text-exporter.tmp.$frq.$$"
			else
				sed -i -e "s/|/,/" "/tmp/informix-text-exporter.tmp.$frq.$$"
			fi
		done

		if [ "$sl_exists" -eq 0 ]
		then
			if [ -s static_labels ]
			then
				if [ "$commas" -eq 0 ]
				then
					sed -i -e "s/^/$metricname{$statics\"} /" "/tmp/informix-text-exporter.tmp.$frq.$$"
				else
					sed -i -e "s/^/$metricname{$statics,/" "/tmp/informix-text-exporter.tmp.$frq.$$"
				fi
			fi
		fi
	fi
	cat "/tmp/informix-text-exporter.tmp.$frq.$$" >> "/tmp/informix-text-exporter.$frq.$$"

	cnt=$(( cnt + 1 ))
done

sed -i -e 's/} ="/"} /' "/tmp/informix-text-exporter.$frq.$$"
sed -i -e 's/,}=/"} /' "/tmp/informix-text-exporter.$frq.$$"

echo "# HELP informix_exporter_duration How long the Informix exporter takes to run in seconds" >> "/tmp/informix-text-exporter.$frq.$$"
echo "# TYPE informix_exporter_duration gauge" >> "/tmp/informix-text-exporter.$frq.$$"

endtime=$( date +%s )
dur=$(( endtime - starttime ))

echo "informix_exporter_duration{$statics,frequency=$frq\"} $dur" >> "/tmp/informix-text-exporter.$frq.$$"
sed -i -e 's/,/",/g' "/tmp/informix-text-exporter.$frq.$$"
sed -i -e 's/=/="/g' "/tmp/informix-text-exporter.$frq.$$"

if cat "/tmp/informix-text-exporter.$frq.$$" | promtool check metrics > /tmp/metrics.lint.err 2>&1
then
	:
else
	echo "Prometheus linting error(s). Check /tmp/metrics.lint.err for details"
fi	

mv "/tmp/informix-text-exporter.$frq.$$" "$textfile_path/informix-text-exporter.$frq.prom"
rm "${frq}.lock" 2> /dev/null
exit 0
