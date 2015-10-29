#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

machine="$1"

if [ "$machine" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine\n\n"
  exit 1
fi

settings=$(ssh $machine "cat /opt/erlangelist/erlangelist-settings.sh")
eval $settings

echo "
database:   127.0.0.1:$ERLANGELIST_POSTGRES_PORT
graphite:   127.0.0.1:$ERLANGELIST_GRAPHITE_NGINX_PORT
"

ssh \
  -L $ERLANGELIST_POSTGRES_PORT:127.0.0.1:$ERLANGELIST_POSTGRES_PORT \
  -L $ERLANGELIST_GRAPHITE_NGINX_PORT:127.0.0.1:$ERLANGELIST_GRAPHITE_NGINX_PORT \
  $1 "sleep infinity"
