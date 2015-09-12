#!/bin/bash

set -o pipefail

function start_container {
  docker run \
    --name erlangelist-geoip \
    --rm \
    -p 5458:8080 \
    fiorix/freegeoip:latest
}

function stop_container {
  for container in $(docker ps | grep "erlangelist-geoip" | awk '{print $1}'); do
    docker stop -t 2 $container > /dev/null
  done

  for container in $(docker ps -a | grep "erlangelist-geoip" | awk '{print $1}'); do
    docker rm $container > /dev/null
  done
}

case "$1" in
  start)
    start_container
    ;;

  stop)
    stop_container
    ;;

  ssh)
    docker exec -it erlangelist-geoip /bin/bash
    ;;
esac