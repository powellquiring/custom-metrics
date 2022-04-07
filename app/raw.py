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
