#!/bin/bash

set -o pipefail

function start {
  # generate some files based on the ports defined in ports.exs
  MIX_ENV=prod elixir \
    -e 'Application.start(:mix)' \
    -r ../site/config/settings.exs \
    -e 'File.write!("../provisioning/remote_files/erlangelist-settings.sh", Erlangelist.Settings.env_vars)'

  . ../provisioning/remote_files/erlangelist-settings.sh

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