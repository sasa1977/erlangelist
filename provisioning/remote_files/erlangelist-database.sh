#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

START_ARGS="
  -p 5459:5432
  erlangelist/database
" container_ctl erlangelist-database "$@"
