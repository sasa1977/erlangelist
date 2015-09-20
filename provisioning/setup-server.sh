#!/bin/bash

set -o pipefail

cd $(dirname ${BASH_SOURCE[0]})

machine="$1"

if [ "$machine" == "" ]; then
  printf "\nSyntax:\n\n  ${BASH_SOURCE[0]} target_machine\n\n"
  exit 1
fi

# generate some files based on the ports defined in ports.exs
elixir \
  -r ../site/config/ports.exs \
  -e '
    File.write!("remote_files/erlangelist-ports.sh",
      for {type, port} <- Erlangelist.Ports.all do
        "export ERLANGELIST_#{String.upcase(to_string(type))}_PORT=#{port}\n"
      end
    )
  '

elixir \
  -r ../site/config/ports.exs \
  -e '
    File.write!("remote_files/collectd.conf",
      File.read!("remote_files/collectd.conf.eex")
      |> EEx.eval_string
    )
  '

ansible-playbook -v -i "$1," playbook.yml
