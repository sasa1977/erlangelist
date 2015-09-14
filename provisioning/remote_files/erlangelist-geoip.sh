#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  -p 5458:8080
  erlangelist/geoip:latest
" container_ctl erlangelist-geoip "$@"
