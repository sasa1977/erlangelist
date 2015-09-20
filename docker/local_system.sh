#!/bin/bash

set -o pipefail

function start {
  elixir -r ../site/config/ports.exs -e "Erlangelist.Ports.generate_export_script"
  ./build-images.sh

  ../provisioning/remote_files/erlangelist-database.sh startd
  ../provisioning/remote_files/erlangelist-geoip.sh startd
  ../provisioning/remote_files/erlangelist-graphite.sh startd
  ../provisioning/remote_files/erlangelist-site.sh startd
}

function stop {
  ../provisioning/remote_files/erlangelist-site.sh stop &
  ../provisioning/remote_files/erlangelist-graphite.sh stop &
  ../provisioning/remote_files/erlangelist-geoip.sh stop &
  ../provisioning/remote_files/erlangelist-database.sh stop &
  wait
}

cd $(dirname ${BASH_SOURCE[0]})

case "$1" in
  start)
    start
    ;;

  stop)
    stop $1
    ;;

  *)
    echo "${BASH_SOURCE[0]} start | stop"
esac