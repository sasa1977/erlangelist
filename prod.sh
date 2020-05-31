#!/bin/bash

set -o pipefail

machine="$1"
shift

if [ "$machine" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine log | iex\n\n"
  exit 1
fi

case "$1" in
  iex)
    ssh -t $machine "sudo docker exec -it erlangelist-site /erlangelist/bin/erlangelist remote"
    ;;

  log)
    ssh $machine "sudo journalctl -u erlangelist-site.service --no-pager --follow"
    ;;

  *)
    echo "Unknown command $1"
    exit 1
    ;;
esac
