# informix-text-exporter
Prometheus Exporter for Informix that uses the Node Exporter Textfile Collector

**Usage:**

Add a cron job that runs every minute for `/path/to/ifx-text-exporter.sh`

The implementation of Prometheus and the Node Exporter is left as an exercise for the reader. :-)

Dependencies:
 -  Prometheus
 -  Node Exporter
 -  jq

**Configuration of the Exporter:**

This file is called `ifx-text-exporter.config` and needs to be in the `informix-text-exporter` directory

`TEXTFILE_DIRECTORY /path/to/place/where/prometheus/looks/for/text/files/` (e.g. `TEXTFILE_DIRECTORY=/var/lib/node_exporter/textfile_collector/`)

**Static Labels:**

You can create a set of static labels that will be applied to every single metric. For example, let's assume you have an HDR cluster of servers in each state in the US and you want to track which specific server this metric is for. You could have a static label file on each box that specifies something like `informix_hostname=informix-<servernum>.<statename>.foo.com`, e.g. `informix_hostname=informix-02.mn.foo.com`
  
The file should be called `static_labels` and needs to be in the `informix-text-exporter` directory.

**Metric Configuration File Layout:**

This should be a JSON file, containing the following keys and associated values:

`metricname` (e.g. `customer_count`)

`frequency` put the number of times per hour to run this, valid values are 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60 (e.g. `1`)

`help` put the help line for metricname here (e.g. `This is the number of customers`)

`type` put the data type for metricname here (e.g. `gauge`)

`database` name of the database to run your SQL against here (e.g. `stores`)

sql select goes here (e.g. `select count(*) from customers`)

A sample configuration file is provided.
