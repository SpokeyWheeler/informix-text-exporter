#!/bin/bash

nummetrics=$( jq '. | length' < metrics.json )
mins=$( date +%M )
cnt=0

while [ "$cnt" -lt "$nummetrics" ]
do
	frequency=$( jq --argjson cnt "$cnt" '.[$cnt] | .frequency' < metrics.json | tr -d \" )
	isnow=$(( mins % ( 60 / frequency ) ))

	if [ "$isnow" -eq 0 ]
	then
		if [ -f "./${frequency}.lock" ]
		then
			:
		else
			./informix-text-exporter.sh "$frequency" &
			touch "${frequency}.lock"
		fi
	fi

	cnt=$(( cnt + 1 ))
done
