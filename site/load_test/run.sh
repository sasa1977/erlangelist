#!/bin/bash

docker run --rm --net=host \
  -v $(pwd)/load_test:/data \
  williamyeh/wrk \
  --latency -d 10 -t 8 -c 8 -s wrk.lua https://localhost:20443
