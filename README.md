# VPC Instance custom metrics monitoring example

This example uses the IBM Cloud Monitoring service to display custom metrics created by an application running on a VPC Virtual Server Instance.

![alt](./xdocs/architecture-architecture.png)

## Create resources

Create the following resources in the IBM cloud:
- [Monitoring](https://cloud.ibm.com/observe/monitoring) instance
- [Virtual Server Instance](https://cloud.ibm.com/vpc-ext/compute/vs) and a Floating IP.  This example is based on the ibm-ubuntu-20-04-3-minimal-amd64-2 image.  You can create the VPC resources required using the cloud console or use the terraform configuration in the [terraform/](./terraform/README.md) directory.

## Install the monitoring agent on the instance
To install the monitoring agent, dragent, on the instance check out the instructions in the cloud Monitoring instance and follow through on the VPC instance:

- Find the instructions provided in the IBM Cloud Console, by selecting your [Monitoring](https://cloud.ibm.com/observe/monitoring) instance, click **Monitoring sources** on the left and click the **Linux** tab.  See [Deploying a monitoring agent](https://test.cloud.ibm.com/docs/monitoring?topic=monitoring-config_agent) for more help.
- ssh to the instance through the Floating IP and copy/paste the agent installation instructions.

Verify the installation of the agent: dragent:
- Check the content of /opt/draios/etc/dragent.yaml to find the Monitoring collector, customerid (ingestion key), etc.

```
cd /opt/draios/etc
cat dragent.yaml
customerid: 12345678-1234-1234-1234-123456789012
collector: ingest.us-south.monitoring.cloud.ibm.com
collector_port: 6443
ssl: true
sysdig_capture_enabled: false
```

- Check the logs to see if you notice anything alarming like Warnings or Errors
```
cd /opt/draios/logs
less draios.log
```

## Add prometheus or statsd stats to your application
The dragent is a statsd server and can be configured as a prometheus forwarder. Modern programming languages have open source libraries for both statsd client and prometheus exporter. For python:
- [python prometheus client](https://pypi.org/project/prometheus-client/)
- [python statsd client](https://pypi.org/project/statsd/)

Install and verify python and pip.
```
apt update -y
apt install python -y
apt install python3-pip -y
```

Check the versions.  Something like:
```
root@custom2:/opt/draios/logs# python3 --version
Python 3.8.10
root@custom2:/opt/draios/logs# pip3 --version
pip 20.0.2 from /usr/lib/python3/dist-packages/pip (python 3.8)
```

Install the prometheus and statsd client support:
```
pip3 install prometheus-client
pip3 install statsd
```

The example python program uses both prometheus and statsd.  You can copy/paste the lines below to create an example.py program and make it executable:

```
cd; # go to home directory /root on ubuntu
cat > example.py <<EOF
#!/usr/bin/env python3
from prometheus_client import start_http_server, Histogram
import prometheus_client
from statsd import StatsClient
import random
import time

# a uniform distribution of buckets from 1 to 10
buckets = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, prometheus_client.utils.INF)
h = Histogram('custom_histogram', 'application prometheus example', buckets=buckets)
statsd = StatsClient()

sleep_time = 0.10
# it is also possible to decorate this function with either statsd or prometheus decorators
def process_observe():
    r = random.betavariate(2, 5); # random number 0..1 with a distribution similar to processing times
    # print(r)
    h.observe(r * 10.0); # scale up to the bucket sizes 1..10
    statsd.timing('custom_timing', r * 1000.0); #timing wants milliseconds
    time.sleep(sleep_time); # slow down a little, adjust sleep_time to increase data flow

prometheus_port = 8000
if __name__ == '__main__':
    print(f"Start up the prometheus collection server.  Have you created the /opt/draios/etc/prometheus.yaml, see README.md, for port {prometheus_port}?")
    start_http_server(prometheus_port)

    # Generate some requests.
    while True:
        process_observe()
EOF
chmod 775 ./example.py
```

Then run the example python program, it should look like this:

```
root@custom2:~# ./example.py
Start up the prometheus collection server.  Have you created the /opt/draios/etc/prometheus.yaml, see README.md, for port 8000?
```

## Verify the python application 
The python application is running.  Open another ssh session to the instance.

You can see the metrics being generated on port 8000 as promised by the message printed by the application:
```
curl localhost:8000/metrics
```

It should look about like this:
```
root@custom2:~# curl localhost:8000/metrics
# HELP python_gc_objects_collected_total Objects collected during gc
# TYPE python_gc_objects_collected_total counter
python_gc_objects_collected_total{generation="0"} 66.0
python_gc_objects_collected_total{generation="1"} 290.0
...
# TYPE custom_histogram histogram
custom_histogram_bucket{le="1.0"} 170.0
custom_histogram_bucket{le="2.0"} 472.0
custom_histogram_bucket{le="3.0"} 781.0
custom_histogram_bucket{le="4.0"} 1041.0
custom_histogram_bucket{le="5.0"} 1204.0
custom_histogram_bucket{le="6.0"} 1301.0
custom_histogram_bucket{le="7.0"} 1333.0
custom_histogram_bucket{le="8.0"} 1344.0
custom_histogram_bucket{le="9.0"} 1346.0
custom_histogram_bucket{le="10.0"} 1346.0
custom_histogram_bucket{le="+Inf"} 1346.0
custom_histogram_count 1346.0
custom_histogram_sum 3792.8247014057697
# HELP custom_histogram_created application prometheus example
# TYPE custom_histogram_created gauge
custom_histogram_created 1.649255010967102e+09
```

Curl a few times to verify the metrics are changing

Note the buckets capture counts for the bucket values. Each bucket catches all values less or equal to the bucket **le** value.  Check out [Histograms and Summaries](https://prometheus.io/docs/practices/histograms/#histograms-and-summaries) for more background.

# Configure the dragent to scrape the application

Copy and pase the content below to complete these tasks:
- cd /opt/draios/etc and take a look at the contents
- create a prometheus.yaml file requesting a scrape of port 8000, same as application
- restart the dragent
```
cd /opt/draios/etc
ls
cat > prometheus.yaml << EOF
scrape_configs:
  - job_name: python
    static_configs:
      - targets: [127.0.0.1:8000]
EOF
service dragent restart
```

No statds configuration required - the dragent is configured as a statsd server by default.

# Using the Monitoring instance in the cloud
Open the [Monitoring](https://cloud.ibm.com/observe/monitoring) and click **Open dashboard** on your instance to start exploring the metrics.

## Explore statsd custom_timing 
Check out the statsd metrics sent by the application through the agent to the monitoring instance.

- Click on **Explore** on the left
- Verify and select your instance name, mine is **custom2**
- Search for **custom_timnig** the statsd metric the application is collecting
- Change the aggregation values between Average, Minimmum, Maximum to get a feel for the data that is being captured

![image](https://user-images.githubusercontent.com/6932057/162022164-e9c4e0b5-f09e-410b-91fb-ec5f342689ae.png)

## Explore Prometheus histogram using PromQL Query
Check out the prometheus metrics hosted by the application and scraped by the agent and sent to the monitoring instance.
- Click on **Explore** on the left
- Click **PromQL Query** on the top
- type: rate(custom_histogram_bucket[$__interval]) 
- Click the **5M** interval on the bottom

You should see a graph of each of the histogram buckets created in the application from le="1.0".."10.0".  The counts being accumulated in the buckets is ever increasing.  The rate() function shows the change in the bucket size during the interval so the lines are not rising in general over time.  The number of items placed in any bucket is controlled by both the random value generated and how frequently the call is made.  The frequency is determined by **sleep_time** varable in the example.py:

```
sleep_time = 0.10
```

Change this from 0.10 to 1.0 and wait for the drop from the le="10.0" bucket change from about 10 to about 1.

Try the following PromQL Query:

```
min(custom_histogram_bucket{le="4.0"}) / avg(custom_histogram_count)
```

This shows only the bucket 4.0 and divides by the histogram count.  The histogram count is incremented each time an item is put into the buckets.  The number in this case will capture the percent of items that fall into the bucket reguardless of the collection rate.  Toggle the 

Read up on [PromQL Explorer](https://prometheus.io/docs/prometheus/latest/querying/basics/) and IBM Monitoring


More on [PromQL Explorer](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## Alerting

The following query will find cases where there is more increase in the 10.0 bucket then the 9.0.  Based on the random number being generated that should not happen frequently:

```
sum(increase(custom_histogram_bucket{le="10.0"}[1m])) - sum(increase(custom_histogram_bucket{le="9.0"}[1m])) 
```

![image](https://user-images.githubusercontent.com/6932057/162046879-312d58f9-b0be-42a3-ac89-27dd3c340067.png)

I could be notified when this happens using the alerts.  Click **Alert** on the left side and configure an email alert when the difference above is > 0:

![image](https://user-images.githubusercontent.com/6932057/162047590-400dc72e-5f46-4f0f-857a-ac60f6c7d7a5.png)

If you run out of patience waiting for an alert, change the query to something that happens more frequently or change the values in the example.py running on the instance.

# Node exporter example

There are prometheus exporters that can collect data from the instance.  The [Node exporter](https://github.com/prometheus/node_exporter) can be used to get some additional data.

Ssh to the instance.  Follow the [MONITORING LINUX HOST METRICS WITH THE NODE EXPORTER](https://prometheus.io/docs/guides/node-exporter/) instructions.

Recent experience:

```
ver=1.3.1
ne=node_exporter-$ver.linux-amd64
wget https://github.com/prometheus/node_exporter/releases/download/v$ver/$ne.tar.gz
tar xvfz $ne.tar.gz
cd $ne
./node_exporter
```

The last few lines output by the node_exporter indicate the port that must be scraped by dragent:

```
...
ts=2022-04-06T19:00:30.625Z caller=node_exporter.go:199 level=info msg="Listening on" address=:9100
ts=2022-04-06T19:00:30.625Z caller=tls_config.go:195 level=info msg="TLS is disabled." http2=false
```

Add this port to the dragent configuration:

```
cd /opt/draios/etc
ls
cat > prometheus.yaml << EOF
scrape_configs:
  - job_name: python
    static_configs:
      - targets: [127.0.0.1:8000]
  - job_name: node_exporter
    static_configs:
      - targets: [127.0.0.1:9100]
EOF
```

You will notice in a few seconds that the **promscrape.yaml** file is updated with the addition of 9100 port.  In a few minutes check the Monitoring intance dashboard.  Query for **process_cpu_seconds_total** for the last 10 seconds to observe a graph like this one:

![image](https://user-images.githubusercontent.com/6932057/162051711-866f0e08-4e8b-4fa8-a831-bf6df854f8ba.png)

