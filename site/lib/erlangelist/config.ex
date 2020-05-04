defmodule Erlangelist.Config do
  use Provider,
    source: Provider.SystemEnv,
    params: [
      # ACME certification settings
      {:certify, type: :boolean, default: true, test: false},
      {:ca_url, default: "localhost"},
      {:email, default: "mail@foo.bar"},
      {:domain, default: "localhost"},
      {:extra_domains, default: "localhost"}
    ]
end
