#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

machine="$1"
external_network_interface="$2"

if [ "$machine" == "" ] || [ "$external_network_interface" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine external_network_interface\n\n"
  exit 1
fi

echo "export ERLANGELIST_NETWORK_IF=$external_network_interface" > remote_files/erlangelist-settings.sh
echo "export ERLANGELIST_SITE_HTTP_PORT=20080" >> remote_files/erlangelist-settings.sh

ansible-playbook -v -i "$machine," playbook.yml
