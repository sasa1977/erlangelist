#!/bin/bash

set -eo pipefail

function beam_running {
  {
    pgrep beam > /dev/null && echo "running"
  } || echo "not running"
}

function polite_stop {
  /erlangelist/bin/erlangelist rpc init stop
  while [ "$(beam_running)" == "running" ]; do sleep 1; done
}

trap polite_stop SIGTERM

/erlangelist/bin/erlangelist foreground &
while [ "$(beam_running)" == "not running" ]; do sleep 1; done
echo "Site running"
while [ "$(beam_running)" == "running" ]; do sleep 1; done