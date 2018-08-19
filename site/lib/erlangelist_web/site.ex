defmodule ErlangelistWeb.Site do
  @behaviour SiteEncrypt
  import EnvHelper

  @doc false
  def child_spec(_), do: SiteEncrypt.Phoenix.child_spec({__MODULE__, ErlangelistWeb.Endpoint})

  def https_keys(), do: SiteEncrypt.https_keys(config())

  def certbot_folder(), do: Erlangelist.db_path("certbot")

  def cert_folder(), do: Erlangelist.priv_path("cert")

  @impl SiteEncrypt
  def config() do
    %{
      run_client?: env_specific(test: false, else: true),
      ca_url: get_os_env("CA_URL", local_acme_server()),
      domain: domain(),
      extra_domains: extra_domains(),
      email: get_os_env("EMAIL", "mail@foo.bar"),
      base_folder: certbot_folder(),
      cert_folder: cert_folder(),
      renew_interval: :timer.hours(6),
      log_level: :info
    }
  end

  @impl SiteEncrypt
  def handle_new_cert(), do: Erlangelist.Backup.backup(certbot_folder())

  defp local_acme_server(), do: {:local_acme_server, %{adapter: Plug.Adapters.Cowboy, port: 20081}}

  defp domain(), do: get_os_env("DOMAIN", "localhost")
  defp extra_domains(), do: get_os_env("EXTRA_DOMAINS", "") |> String.split(",") |> Enum.reject(&(&1 == ""))

  defp get_os_env(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> value
    end
  end
end
