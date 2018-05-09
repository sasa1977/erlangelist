defmodule ErlangelistWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :erlangelist

  socket("/socket", ErlangelistWeb.UserSocket)

  plug(Plug.Static, at: "/", from: :erlangelist, gzip: false, only: ~w(css fonts images js favicon.ico robots.txt))
  plug(SiteEncrypt.AcmeChallenge, __MODULE__)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Logger)

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
    case SiteEncrypt.Certbot.https_keys(certbot_config()) do
      {:ok, keys} -> {:ok, Keyword.merge(config, https: [port: 20443] ++ keys)}
      :error -> {:ok, config}
    end
  end

  def certbot_config() do
    %{
      run_client?: unquote(Mix.env() != :test),
      ca_url: "http://localhost:4000/directory",
      domain: "theerlangelist.com",
      extra_domains: ["www.theerlangelist.com"],
      email: "mail@foo.bar",
      base_folder: Path.join(Application.app_dir(:erlangelist, "priv"), "certbot"),
      renew_interval: :timer.hours(6)
    }
  end
end
