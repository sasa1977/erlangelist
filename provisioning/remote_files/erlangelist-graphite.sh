#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  -p $ERLANGELIST_GRAPHITE_NGINX_PORT:80
  -p $ERLANGELIST_CARBON_PORT:2003
  -p $ERLANGELIST_STATSD_PORT:8125/udp
  -v /erlangelist/persist/graphite/storage:/opt/graphite/storage
  erlangelist/graphite:latest
  /home/root/start.sh
" container_ctl erlangelist-graphite "$@"
