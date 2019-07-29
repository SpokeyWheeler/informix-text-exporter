# informix-text-exporter
Prometheus Exporter for Informix that uses the Node Exporter Textfile Collector

Usage:

Add a cron job that runs every minute for /path/to/ifx-tf-exporter.sh

Configuration File Layout:

[metricname]
HELP put your help line for metricname here
TYPE 
[end of metricname]
