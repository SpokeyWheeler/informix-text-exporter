# informix-text-exporter
Prometheus Exporter for Informix that uses the Node Exporter Textfile Collector

Usage:

Add a cron job that runs every minute for /path/to/ifx-tf-exporter.sh

Configuration File Layout:

[metricname]

HELP put the help line for metricname here
TYPE put the data type for metricname here
DATABASE name of the database to run your SQL against here
SQL select goes here

[end of metricname]
