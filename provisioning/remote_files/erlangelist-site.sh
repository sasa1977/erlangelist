#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  --add-host=\"erlangelist.site:127.0.0.1\"
  -p 5454:5454 -p 4369:4369 -p 30000:30000
  erlangelist/site:latest
  /erlangelist/bin/erlangelist foreground
" container_ctl erlangelist-site "$@"
