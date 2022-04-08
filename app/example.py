#!/usr/bin/env python3

# example.py - collect metrics from a simple application

import prometheus_client
import statsd
import random
import time

# a uniform distribution of buckets from 1 to 10
buckets = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, prometheus_client.utils.INF)
h = prometheus_client.Histogram('custom_histogram', 'application prometheus example', buckets=buckets)
statsd = statsd.StatsClient()

@ h.time()
def prometheus_example(i):
    r = random.betavariate(2, 5); # random number 0..1 with a distribution similar to processing times
    time.sleep(r * 10.0)

@statsd.timer("custom_timing")
def statsd_example(i):
    r = random.betavariate(2, 5); # random number 0..1 with a distribution similar to processing times
    time.sleep(r * 1.0)

prometheus_port = 8000
if __name__ == '__main__':
    print(f"Start up the prometheus collection server.  Have you created the /opt/draios/etc/prometheus.yaml, see README.md, for port {prometheus_port}?")
    prometheus_client.start_http_server(prometheus_port)

    # Generate some requests.
    i = 0
    while True:
      prometheus_example(i)
      i += 1
      statsd_example(i)
      i += 1