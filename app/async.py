#!/usr/bin/env python3

# async.py - collect metrics from an application built on asyncio

import asyncio
import queue
import random
from prometheus_client import start_http_server, Histogram
import prometheus_client
from statsd import StatsClient

# number of example_ functions to run simultaneously
simultaneous = 10

buckets = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, prometheus_client.utils.INF)
h = Histogram('custom_histogram', 'application prometheus example', buckets=buckets)
statsd = StatsClient()

async def prometheus_example(i):
  with h.time():
    r = random.betavariate(2, 5); # random number 0..1 with a distribution similar to processing times
    await asyncio.sleep(r * 10.0)
    #print(f"prometheus_example {i} done")

async def statsd_example(i):
  with statsd.timer("custom_timing"):
    r = random.betavariate(2, 5); # random number 0..1 with a distribution similar to processing times
    await asyncio.sleep(r * 1.0)
    #print(f"statsd_example {i} done")

#--------------------------------------------------------------------------------------------
# Code to simulatenously run multiple copies of the two examples above
# 

async def runner(example, simultaneous):
  """ example - function to run, simultaneous - number of active functions"""
  l = [asyncio.create_task(example(i)) for i in range(simultaneous)]
  i = simultaneous
  while True:
    #print(f"total:{i}")
    done, pending = await asyncio.wait(l, return_when=asyncio.FIRST_COMPLETED)
    l = list(pending) + [asyncio.create_task(example(t)) for t in range(i, i + len(done))]
    i = i + len(done)

async def main():
  await asyncio.wait([asyncio.create_task(runner(prometheus_example, simultaneous)), asyncio.create_task(runner(statsd_example, simultaneous))], return_when=asyncio.ALL_COMPLETED)

prometheus_port = 8000
if __name__ == '__main__':
    print(f"Start up the prometheus collection server.  Have you created the /opt/draios/etc/prometheus.yaml, see README.md, for port {prometheus_port}?")
    start_http_server(prometheus_port)
    asyncio.run(main())

