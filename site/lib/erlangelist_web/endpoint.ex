defmodule ErlangelistWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :erlangelist

  socket("/socket", ErlangelistWeb.UserSocket)

  plug(SiteEncrypt.AcmeChallenge, __MODULE__)
  plug(Plug.Static, at: "/", from: :erlangelist, gzip: false, only: ~w(css fonts images js favicon.ico robots.txt))

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Logger, log: :debug)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(ErlangelistWeb.Router)

  def init(_key, config) do
    config =
      case SiteEncrypt.Certbot.https_keys(certbot_config()) do
        {:ok, keys} ->
          Keyword.merge(config, https: [port: 20443] ++ Application.get_env(:erlangelist, :https_options, []) ++ keys)

        :error ->
          config
      end

    {:ok, config}
  end

  def certbot_config() do
    %{
      run_client?: unquote(Mix.env() != :test),
      ca_url: os_setting("CA_URL", Erlangelist.AcmeServer.directory_url()),
      domain: os_setting("DOMAIN", "localhost"),
      extra_domains: os_setting("EXTRA_DOMAINS", "") |> String.split(",") |> Enum.reject(&(&1 == "")),
      email: os_setting("EMAIL", "mail@foo.bar"),
      base_folder: cert_folder(),
      renew_interval: :timer.hours(6)
    }
  end

  def handle_new_cert(certbot_config) do
    SiteEncrypt.Phoenix.restart_endpoint(certbot_config)
    Erlangelist.Backup.backup(certbot_config.base_folder)
  end

  def cert_folder(), do: Erlangelist.db_path("certbot")

  defp os_setting(name, default) do
    case System.get_env(name) do
      nil -> default
      "" -> default
      value -> value
    end
  end
end
