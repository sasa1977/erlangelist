#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

machine="$1"

if [ "$machine" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine\n\n"
  exit 1
fi

ansible-playbook -v -i "$1," playbook.yml
