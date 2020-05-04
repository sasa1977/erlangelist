defmodule ErlangelistWeb.Blog.SSL do
  @behaviour SiteEncrypt

  def keys(), do: SiteEncrypt.https_keys(config())
  def certbot_folder(), do: Erlangelist.db_path("certbot")
  def cert_folder(), do: Erlangelist.priv_path("cert")

  @impl SiteEncrypt
  def config() do
    %{
      run_client?: Erlangelist.Config.certify(),
      ca_url: with("localhost" <- Erlangelist.Config.ca_url(), do: local_acme_server()),
      domain: Erlangelist.Config.domain(),
      extra_domains: extra_domains(),
      email: Erlangelist.Config.email(),
      base_folder: certbot_folder(),
      cert_folder: cert_folder(),
      renew_interval: :timer.hours(6),
      log_level: :info
    }
  end

  @impl SiteEncrypt
  def handle_new_cert(), do: Erlangelist.Backup.backup(certbot_folder())

  defp local_acme_server(), do: {:local_acme_server, %{adapter: Plug.Adapters.Cowboy, port: 20081}}

  defp extra_domains(), do: Erlangelist.Config.extra_domains() |> String.split(",") |> Enum.reject(&(&1 == ""))
end
