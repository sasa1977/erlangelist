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

  plug(ErlangelistWeb.MovePermanently, from: "theerlangelist.com", to: "www.theerlangelist.com")

  plug(ErlangelistWeb.Router)

  def http_port(), do: 20080
  def https_port(), do: 20443
  def domains(), do: [domain() | extra_domains()]

  def init(_key, app_env_config), do: {:ok, endpoint_config(app_env_config)}

  defp endpoint_config(app_env_config) do
    common_config()
    |> DeepMerge.deep_merge(app_env_config)
    |> configure_https()
  end

  defp common_config() do
    [
      http: [compress: true, port: http_port()],
      render_errors: [view: ErlangelistWeb.ErrorView, accepts: ~w(html json)],
      pubsub: [name: Erlangelist.PubSub, adapter: Phoenix.PubSub.PG2]
    ]
  end

  defp configure_https(config) do
    case SiteEncrypt.Certbot.https_keys(certbot_config()) do
      {:ok, keys} -> DeepMerge.deep_merge(config, https: [compress: true, port: https_port()] ++ keys)
      :error -> Keyword.delete(config, :https)
    end
  end

  def certbot_config() do
    %{
      run_client?: unquote(Mix.env() != :test),
      ca_url: get_os_env("CA_URL", Erlangelist.AcmeServer.directory_url()),
      domain: domain(),
      extra_domains: extra_domains(),
      email: get_os_env("EMAIL", "mail@foo.bar"),
      base_folder: cert_folder(),
      renew_interval: :timer.hours(6),
      log_level: :info
    }
  end

  def handle_new_cert(certbot_config) do
    SiteEncrypt.Phoenix.restart_endpoint(certbot_config)
    Erlangelist.Backup.backup(certbot_config.base_folder)
  end

  def cert_folder(), do: Erlangelist.db_path("certbot")

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
