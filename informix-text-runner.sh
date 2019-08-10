#/bin/bash

nummetrics=$( cat metrics.json | jq '. | length' )
mins=$( date +%M )
echo $mins
cnt=0

while [ "$cnt" -lt "$nummetrics" ]
do
	frequency=$( cat metrics.json | jq --argjson cnt "$cnt" '.[$cnt] | .frequency' | tr -d \" )
	isnow=$(( mins % ( 60 / frequency ) ))

	if [ "$isnow" -eq 0 ]
	then
		if [ -f ./${frequency}.lock ]
		then
			:
		else
			./informix-text-exporter.sh $frequency &
			> ${frequency}.lock
		fi
	fi

	cnt=$(( cnt + 1 ))
done
