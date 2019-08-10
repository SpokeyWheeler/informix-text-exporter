#!/bin/bash

starttime=$( date +%s%3N )

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

textfile_path=$( jq '.[] | .textfile_path' < config.json | tr -d \" )

nummetrics=$( jq '. | length' < metrics.json )
cnt=0

ls -l static_labels > /dev/null 2>&1
sl_exists=$?

if [ $sl_exists -eq 0 ]
then
	statics=$( cat static_labels )
fi

cat / dev/null > "/tmp/informix-text-exporter.$frq.$$"

while [ "$cnt" -lt "$nummetrics" ]
do
	commas=0
	frequency=$( jq --argjson cnt "$cnt" '.[$cnt] | .frequency' < metrics.json | tr -d \" )

	if [ "$frequency" -eq "$frq" ]
	then

		metricname=$( jq --argjson cnt "$cnt" '.[$cnt] | .metricname' < metrics.json | tr -d \" )
		help=$( jq --argjson cnt "$cnt" '.[$cnt] | .help' < metrics.json | tr -d \" )
		type=$( jq --argjson cnt "$cnt" '.[$cnt] | .type' < metrics.json | tr -d \" )
		database=$( jq --argjson cnt "$cnt" '.[$cnt] | .database' < metrics.json | tr -d \" )
		sql=$( jq --argjson cnt "$cnt" '.[$cnt] | .sql' < metrics.json | tr -d \" )

		echo "# HELP $metricname $help" >> "/tmp/informix-text-exporter.$frq.$$"
		echo "# TYPE $metricname $type" >> "/tmp/informix-text-exporter.$frq.$$"

		origsql=$sql
		newsql=$sql

		for i in $newsql
		do
			j=$( echo "$i" | tr "[:upper:]" "[:lower:]" )
			if [ "x$j" == "xselect" ]
			then
				sql="$i '${metricname}', "
			else
				if [ "x$j" == "xfrom" ]
				then
					commas=$( echo "$sql" | while read -r x; do echo "$x" | grep -o "," | wc -l; done )
					if [ $(( commas % 2 )) -ne 1 ]
					then
						echo "WARNING: label without value or vice-versa"
					fi
					sql="$sql, '|'"
				fi
				sql="$sql $i"
			fi
		done

		newsql=$origsql

		ccnt=0
		for i in $newsql
		do
			j=$( echo "$i" | tr "[:upper:]" "[:lower:]" )
			if [ "x$j" == "xselect" ]
			then
				sql="$i '"
				sql="${sql}${metricname}"
				sql="${sql}', "
			else
				if [ "$ccnt" -eq "$commas" ]
				then
					if [ "$commas" -gt 1 ]
					then
						sql="$sql'}',"
					fi
				fi
				sql="$sql $i"
			fi
			ccnt=$(( ccnt + 1 ))
		done
		
		if [ "$commas" -eq 1 ]
		then
			dbaccess "$database" <<! 2> /dev/null | grep -v "^$" >> "/tmp/informix-text-exporter.$frq.$$"
OUTPUT TO PIPE "cat" WITHOUT HEADINGS
$sql
!
		else
			pst='paste -d ,= -'
			ccnt=0
			while [ "$ccnt" -le "$commas" ]
			do
				pst="$pst -"
				ccnt=$(( ccnt + 1 ))
			done
			dbaccess "$database" <<! 2> /dev/null | grep -v "^$" | eval "$pst" >> "/tmp/informix-text-exporter.$frq.$$"
OUTPUT TO PIPE "cat" WITHOUT HEADINGS
$sql
!
		fi

		if [ $sl_exists -eq 0 ]
		then
			if [ -s static_labels ]
			then
				if [ "$commas" -eq 1 ]
				then
					sed -i -e "s/^${metricname}/$metricname{$statics\"}/" "/tmp/informix-text-exporter.$frq.$$"
				else
					sed -i -e "s/^${metricname}/$metricname{$statics/" "/tmp/informix-text-exporter.$frq.$$"
				fi
			fi
		fi
	fi

	cnt=$(( cnt + 1 ))
done
sed -i -e 's/} ="/"} /' "/tmp/informix-text-exporter.$frq.$$"
sed -i -e 's/,}=/"} /' "/tmp/informix-text-exporter.$frq.$$"

echo "# HELP informix_exporter_duration How long the Informix exporter takes to run in milliseconds" >> "/tmp/informix-text-exporter.$frq.$$"
echo "# TYPE informix_exporter_duration gauge" >> "/tmp/informix-text-exporter.$frq.$$"

endtime=$( date +%s%3N )
dur=$(( endtime - starttime ))

echo "informix_exporter_duration{$statics,frequency=$frq\"} $dur" >> "/tmp/informix-text-exporter.$frq.$$"
sed -i -e 's/,/",/g' "/tmp/informix-text-exporter.$frq.$$"
sed -i -e 's/=/="/g' "/tmp/informix-text-exporter.$frq.$$"

mv "/tmp/informix-text-exporter.$frq.$$" "$textfile_path/informix-text-exporter.$frq.prom"
rm "${frq}.lock" 2> /dev/null
exit 0
