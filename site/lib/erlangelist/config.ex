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

  def backup_folder, do: priv_path("backup")
  def usage_stats_folder, do: db_path("usage_stats")

  def db_path, do: Path.join(Application.app_dir(:erlangelist, "priv"), "db")
  def db_path(name), do: Path.join(db_path(), name)

  defp priv_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv") | parts])
  defp priv_path(name), do: priv_path([name])
end
