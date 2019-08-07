#/bin/bash

nummetrics=$( cat informix-text-exporter.json | jq '. | length' )
mins=$( date +M )
cnt=0

ls -l static_labels > /dev/null 2>&1
sl_exists=$?

> /tmp/informix-text-exporter.$$

while [ "$cnt" -lt "$nummetrics" ]
do
	commas=0
	frequency=$( cat informix-text-exporter.json | jq --argjson cnt "$cnt" '.[$cnt] | .frequency' | tr -d \" )
	isnow=$(( mins % ( 60 / frequency ) ))

	# if [ "$isnow" -eq 0 ]
	# then

		metricname=$( cat informix-text-exporter.json | jq --argjson cnt "$cnt" '.[$cnt] | .metricname' | tr -d \" )
		help=$( cat informix-text-exporter.json | jq --argjson cnt "$cnt" '.[$cnt] | .help' | tr -d \" )
		type=$( cat informix-text-exporter.json | jq --argjson cnt "$cnt" '.[$cnt] | .type' | tr -d \" )
		database=$( cat informix-text-exporter.json | jq --argjson cnt "$cnt" '.[$cnt] | .database' | tr -d \" )
		sql=$( cat informix-text-exporter.json | jq --argjson cnt "$cnt" '.[$cnt] | .sql' | tr -d \" )

		echo "# HELP $metricname $help" >> /tmp/informix-text-exporter.$$
		echo "# TYPE $metricname $type" >> /tmp/informix-text-exporter.$$

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
					echo $commas
					echo $rmdr
					if [ $(( commas % 2 )) -ne 1 ]
					then
						echo "WARNING: label without value or vice-versa"
					fi
					sql="$sql, '|'"
				fi
				sql="$sql $i"
			fi
		done
echo $sql 
sleep 2
		
		dbaccess $database <<! | grep -v "^$" >> /tmp/informix-text-exporter.$$
OUTPUT TO PIPE "cat" WITHOUT HEADINGS
$sql
!

less /tmp/informix-text-exporter.$$

		if [ $sl_exists -eq 0 ]
		then
			if [ -z static_labels ]
			then
				:
			else
				if [ $commas -eq 1 ]
				then
					sed -i -e "s/^${metricname}/$metricname{`cat static_labels`}/" /tmp/informix-text-exporter.$$
				else
					sed -i -e "s/^${metricname}/$metricname{`cat static_labels`/" /tmp/informix-text-exporter.$$
				fi
			fi
		fi
	# fi

	cnt=$(( cnt + 1 ))
done

less /tmp/informix-text-exporter.$$
# rm /tmp/informix-text-exporter.$$

