#/bin/bash

nummetrics=$( cat informix-text-exporter.json | jq '. | length' )
mins=$( date +M )
cnt=0

> /tmp/informix-text-exporter.$$

while [ "$cnt" -lt "$nummetrics" ]
do
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

		newsql=$( echo $sql | tr "[:upper:]" "[:lower:]" )
		commas=$( echo $newsql | grep -c "," )
		if [ $(( $commas % 2 )) -ne 0 ]
		then
			echo "WARNING: label without value or vice-versa"
			sleep 2
		fi
		for i in $newsql
		do
			if [ $commas -eq 0 ]
			then
				if [ "x$i" == "xselect" ]
				then
					sql="$i \"$metricname\", "
				else
					sql="$sql $i"
				fi
			fi
		done
echo $sql 
sleep 2
		
		dbaccess $database <<! 2> /dev/null | grep -v "^$" >> /tmp/informix-text-exporter.$$
OUTPUT TO PIPE "cat" WITHOUT HEADINGS
$sql
!
	# fi

	cnt=$(( cnt + 1 ))
done

less /tmp/informix-text-exporter.$$
rm /tmp/informix-text-exporter.$$

