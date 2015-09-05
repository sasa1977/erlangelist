#!/bin/bash

set -o pipefail

latest_version=$(docker images | awk "{if (\$1 == \"erlangelist/site\") print \$2}" | sort -g -r | head -n 1)

for container in $(docker ps | grep "erlangelist/site" | awk '{print $1}'); do
  docker stop $container > /dev/null
done

for container in $(docker ps -a | grep "erlangelist/site" | awk '{print $1}'); do
  docker rm $container > /dev/null
done

docker run \
  --name erlangelist_site \
  --rm \
  --add-host="erlangelist.site:127.0.0.1" \
  -p 5454:5454 -p 4369:4369 -p 30000:30000 erlangelist/site:$latest_version \
  /erlangelist/bin/erlangelist foreground
