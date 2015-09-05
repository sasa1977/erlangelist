#!/bin/bash

set -o pipefail

for container in $(docker ps | grep "erlangelist/site" | awk '{print $1}'); do
  docker stop -t 2 $container > /dev/null
done

for container in $(docker ps -a | grep "erlangelist/site" | awk '{print $1}'); do
  docker rm $container > /dev/null
done
