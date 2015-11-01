#!/bin/bash

set -o pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

function stop_container {
  for container in $(docker ps | grep "$1" | awk '{print $1}'); do
    docker exec $1 /erlangelist/bin/erlangelist stop
  done

  for container in $(docker ps | grep "$1" | awk '{print $1}'); do
    docker stop -t 2 $container > /dev/null
  done

  for container in $(docker ps -a | grep "$1" | awk '{print $1}'); do
    docker rm $container > /dev/null
  done
}


if [ $1 == "backup" ]; then
  SITE_HTTP_PORT=$(($ERLANGELIST_SITE_HTTP_PORT + 500))
  INET_DIST_PORT=$(($ERLANGELIST_SITE_INET_DIST_PORT + 500))
  EPMD_PORT=4370
  CONTAINER_NAME="erlangelist-backup-site"
  shift 1
else
  SITE_HTTP_PORT=$ERLANGELIST_SITE_HTTP_PORT
  INET_DIST_PORT=$ERLANGELIST_SITE_INET_DIST_PORT
  EPMD_PORT=4369
  CONTAINER_NAME="erlangelist-site"
fi

if [ "$1" == "console" ]; then
  ARG="console"
else
  ARG="foreground"
fi

START_ARGS="
  --add-host=\"erlangelist.site:127.0.0.1\"
  -p $SITE_HTTP_PORT:$ERLANGELIST_SITE_HTTP_PORT
  -p $INET_DIST_PORT:$ERLANGELIST_SITE_INET_DIST_PORT
  -p $EPMD_PORT:4369
  erlangelist/site:latest $ARG
" container_ctl $CONTAINER_NAME "$@"
