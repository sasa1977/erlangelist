#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  --add-host=\"erlangelist.site:127.0.0.1\"
  -p $ERLANGELIST_SITE_HTTP_PORT:$ERLANGELIST_SITE_HTTP_PORT
  -p $ERLANGELIST_ADMIN_HTTP_PORT:$ERLANGELIST_ADMIN_HTTP_PORT
  -p 4369:4369
  -p $ERLANGELIST_SITE_INET_DIST_PORT:$ERLANGELIST_SITE_INET_DIST_PORT
  erlangelist/site:latest
  /erlangelist/bin/erlangelist foreground
" container_ctl erlangelist-site "$@"
