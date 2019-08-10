#/bin/bash

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
		rm ${frq}.lock 2> /dev/null
		exit 2
			;;
esac

textfile_path=$( cat config.json | jq '.[] | .textfile_path' | tr -d \" )

nummetrics=$( cat metrics.json | jq '. | length' )
cnt=0

ls -l static_labels > /dev/null 2>&1
sl_exists=$?

if [ $sl_exists -eq 0 ]
then
	statics=$( cat static_labels )
fi

> /tmp/informix-text-exporter.$$

while [ "$cnt" -lt "$nummetrics" ]
do
	commas=0
	frequency=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .frequency' | tr -d \" )

	if [ "$frequency" -eq "$frq" ]
	then

		metricname=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .metricname' | tr -d \" )
		help=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .help' | tr -d \" )
		type=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .type' | tr -d \" )
		database=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .database' | tr -d \" )
		sql=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .sql' | tr -d \" )

		echo "# HELP $metricname $help" >> /tmp/informix-text-exporter.$frq.$$
		echo "# TYPE $metricname $type" >> /tmp/informix-text-exporter.$frq.$$

		origsql=$sql
		newsql=$sql

		for i in $newsql
		do
			j=$( echo $i | tr "[:upper:]" "[:lower:]" )
			if [ "x$j" == "xselect" ]
			then
				sql="$i '${metricname}', "
			else
				if [ "x$j" == "xfrom" ]
				then
					commas=$( echo $sql | while read i; do echo $i |grep -o ","| wc -l; done )
					rmdr=$(( $commas % 2 ))
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
			j=$( echo $i | tr "[:upper:]" "[:lower:]" )
			if [ "x$j" == "xselect" ]
			then
				sql="$i '${metricname}', "
			else
				if [ $ccnt -eq $commas ]
				then
					if [ $commas -gt 1 ]
					then
						sql="$sql'}',"
					fi
				fi
				sql="$sql $i"
			fi
			ccnt=$(( ccnt + 1 ))
		done
		
		if [ $commas -eq 1 ]
		then
			dbaccess $database <<! 2> /dev/null | grep -v "^$" >> /tmp/informix-text-exporter.$frq.$$
OUTPUT TO PIPE "cat" WITHOUT HEADINGS
$sql
!
		else
			pst='paste -d ,= -'
			ccnt=0
			while [ $ccnt -le $commas ]
			do
				pst="$pst -"
				ccnt=$(( ccnt + 1 ))
			done
			dbaccess $database <<! 2> /dev/null | grep -v "^$" | eval $pst >> /tmp/informix-text-exporter.$frq.$$
OUTPUT TO PIPE "cat" WITHOUT HEADINGS
$sql
!
		fi

		if [ $sl_exists -eq 0 ]
		then
			if [ -z static_labels ]
			then
				:
			else
				if [ $commas -eq 1 ]
				then
					sed -i -e "s/^${metricname}/$metricname{$statics\"}/" /tmp/informix-text-exporter.$frq.$$
				else
					sed -i -e "s/^${metricname}/$metricname{$statics/" /tmp/informix-text-exporter.$frq.$$
				fi
			fi
		fi
	fi

	cnt=$(( cnt + 1 ))
done
sed -i -e 's/} ="/"} /' /tmp/informix-text-exporter.$frq.$$
sed -i -e 's/,}=/"} /' /tmp/informix-text-exporter.$frq.$$

echo "# HELP informix_exporter_duration How long the Informix exporter takes to run in milliseconds" >> /tmp/informix-text-exporter.$frq.$$
echo "# TYPE informix_exporter_duration gauge" >> /tmp/informix-text-exporter.$frq.$$

endtime=$( date +%s%3N )
dur=$(( endtime - starttime ))

echo "informix_exporter_duration{$statics,frequency=$frq\"} $dur" >> /tmp/informix-text-exporter.$frq.$$
sed -i -e 's/,/",/g' /tmp/informix-text-exporter.$frq.$$
sed -i -e 's/=/="/g' /tmp/informix-text-exporter.$frq.$$

mv /tmp/informix-text-exporter.$frq.$$ $textfile_path/informix-text-exporter.$frq.prom
rm ${frq}.lock 2> /dev/null
exit 0
