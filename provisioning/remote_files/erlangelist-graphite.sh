#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  -p 5455:80
  -p 5456:2003
  -p 5457:8125/udp
  -v /opt/graphite/storage:/opt/graphite/storage
  erlangelist/graphite:latest
  /home/root/start.sh
" container_ctl erlangelist-graphite "$@"
