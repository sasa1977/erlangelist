#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

machine="$1"
external_network_interface="$2"

if [ "$machine" == "" ] || [ "$external_network_interface" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine external_network_interface\n\n"
  exit 1
fi

# generate some files based on the ports defined in ports.exs
MIX_ENV=prod elixir \
  -e 'Application.start(:mix)' \
  -r ../site/config/system_settings.exs \
  -e 'File.write!("remote_files/erlangelist-settings.sh", Erlangelist.SystemSettings.env_vars)'

echo "export ERLANGELIST_NETWORK_IF=$external_network_interface" >> remote_files/erlangelist-settings.sh

MIX_ENV=prod elixir \
  -e 'Application.start(:mix)' \
  -r ../site/config/system_settings.exs \
  -e '
    File.write!("remote_files/collectd.conf",
      File.read!("remote_files/collectd.conf.eex")
      |> EEx.eval_string
    )
  '

ansible-playbook -v -i "$machine," playbook.yml
