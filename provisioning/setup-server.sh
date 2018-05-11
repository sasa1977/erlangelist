#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

machine="$1"
external_network_interface="$2"
server_config_file="$3"

if [ "$machine" == "" ] || [ "$external_network_interface" == "" ] || [ "$server_config_file" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine external_network_interface server_config_file\n\n"
  exit 1
fi

echo "export ERLANGELIST_NETWORK_IF=$external_network_interface" > remote_files/erlangelist-settings.sh
echo "export ERLANGELIST_SITE_HTTP_PORT=20080" >> remote_files/erlangelist-settings.sh
echo "export ERLANGELIST_SITE_HTTPS_PORT=20443" >> remote_files/erlangelist-settings.sh
cat $server_config_file >> remote_files/erlangelist-settings.sh

ansible-playbook -v -i "$machine," playbook.yml
