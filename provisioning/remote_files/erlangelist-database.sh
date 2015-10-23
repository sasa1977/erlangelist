#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  -p $ERLANGELIST_POSTGRES_PORT:5432
  -v /erlangelist/persist/database:/var/lib/postgresql/data
  -e POSTGRES_PASSWORD=$ERLANGELIST_DB_PASSWORD
  erlangelist/database
" container_ctl erlangelist-database "$@"
