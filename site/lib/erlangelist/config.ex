defmodule Erlangelist.Config do
  use Boundary

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

  def priv_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv") | parts])
  def priv_path(name), do: priv_path([name])

  def db_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv"), "db" | parts])
  def db_path(name), do: db_path([name])

  def backup_folder, do: Erlangelist.Config.priv_path("backup")
end
