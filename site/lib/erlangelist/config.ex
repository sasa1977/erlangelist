defmodule Erlangelist.Config do
  use Provider,
    source: Provider.SystemEnv,
    params: [
      # ACME certification settings
      {:certify, type: :boolean, default: true, test: false},
      {:ca_url, default: "localhost"},
      {:email, default: "mail@foo.bar"},
      {:domain, default: "localhost"},
      {:extra_domains, default: "localhost"},

      # blog site
      {:blog_host, default: "localhost"},
      {:blog_ssl_port, type: :integer, default: 443, dev: 20443, test: 443}
    ]
end
