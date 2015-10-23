#!/bin/bash

set -eo pipefail

. $(dirname ${BASH_SOURCE[0]})/docker-helper.sh

function container_ip {
  ip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1)
  while [ "$ip" == "" ]; do
    echo "Waiting for container $1" >&2
    sleep 1
    ip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1)
  done
  echo "$ip"
}

function site_url {
  echo "$(container_ip $1):$ERLANGELIST_SITE_HTTP_PORT"
}

case "$1" in
  start)
    destination=$(site_url $2)
    echo "Redirecting port 80 to $destination"
    iptables -t nat -I PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport 80 -j DNAT --to-destination "$destination"
    ;;

  stop)
    destination=$(site_url $2)
    echo "Removing redirection from port 80 to $destination"
    iptables -t nat -D PREROUTING -i $ERLANGELIST_NETWORK_IF -p tcp --dport 80 -j DNAT --to-destination "$destination" || true
    ;;

  *)
    echo "${BASH_SOURCE[0]} start | stop"
esac


