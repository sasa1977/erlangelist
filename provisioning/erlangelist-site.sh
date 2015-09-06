#!/bin/bash

set -o pipefail

function latest_image_version {
  echo $(docker images |
    awk "{if (\$1 == \"$1\") print \$2}" |
    sort -g -r |
    head -n 1
  )
}

function start_container {
  docker run \
    --name erlangelist-site \
    --rm \
    --add-host="erlangelist.site:127.0.0.1" \
    -p 5454:5454 -p 4369:4369 -p 30000:30000 \
    erlangelist/site:$(latest_image_version erlangelist/site) \
    /erlangelist/bin/erlangelist foreground
}

function stop_container {
  for container in $(docker ps | grep "erlangelist/site" | awk '{print $1}'); do
    docker stop -t 2 $container > /dev/null
  done

  for container in $(docker ps -a | grep "erlangelist/site" | awk '{print $1}'); do
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
    docker exec -it erlangelist-site /bin/sh
    ;;
esac