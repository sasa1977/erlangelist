defmodule ErlangelistWeb.Blog.Endpoint do
  use Phoenix.Endpoint, otp_app: :erlangelist
  use SiteEncrypt.Phoenix
  require Erlangelist.Config

  plug Plug.Static, at: "/", from: :erlangelist, only: ~w(css fonts images js favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.Logger, log: :debug
  plug SiteEncrypt.AcmeChallenge, __MODULE__

  plug :force_ssl

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head

  plug ErlangelistWeb.Plug.MovePermanently, from: "theerlangelist.com", to: "www.theerlangelist.com"

  plug ErlangelistWeb.Blog.Router

  defp force_ssl(conn, _opts) do
    host =
      case Erlangelist.Config.blog_ssl_port() do
        443 -> Erlangelist.Config.blog_host()
        port -> "#{Erlangelist.Config.blog_host()}:#{port}"
      end

    Plug.SSL.call(conn, Plug.SSL.init(host: host, log: :debug, exclude: []))
  end

  @impl Phoenix.Endpoint
  def init(_key, phoenix_defaults), do: {:ok, settings(phoenix_defaults)}

  defp settings(phoenix_defaults) do
    phoenix_defaults
    |> DeepMerge.deep_merge(common_config())
    |> DeepMerge.deep_merge(env_specific_config())
    |> SiteEncrypt.Phoenix.configure_https()
  end

  defp common_config() do
    [
      url: [scheme: "https", host: Erlangelist.Config.blog_host(), port: Erlangelist.Config.blog_ssl_port()],
      http: [compress: true, port: 20080],
      https: [
        compress: true,
        port: 20443,
        cipher_suite: :strong,
        secure_renegotiate: true,
        reuse_sessions: true,
        log_level: :warning
      ],
      render_errors: [view: ErlangelistWeb.Blog.View, accepts: ~w(html json)],
      pubsub_server: Erlangelist.PubSub
    ]
  end

  case Mix.env() do
    :dev ->
      # need to determine assets path at compile time
      @assets_path Path.expand("../../../assets", __DIR__)
      unless File.exists?(@assets_path), do: Mix.raise("Assets not found in #{@assets_path}")

      defp env_specific_config() do
        [
          http: [transport_options: [num_acceptors: 5]],
          https: [transport_options: [num_acceptors: 5]],
          debug_errors: true,
          check_origin: false,
          watchers: [
            node: [
              "node_modules/webpack/bin/webpack.js",
              "--mode",
              "development",
              "--watch-stdin",
              cd: @assets_path
            ]
          ],
          live_reload: [
            patterns: [
              ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
              ~r{priv/gettext/.*(po)$},
              ~r{lib/erlangelist_web/views/.*(ex)$},
              ~r{lib/erlangelist_web/templates/.*(eex)$}
            ]
          ]
        ]
      end

    :test ->
      defp env_specific_config() do
        [
          server: true,
          http: [port: 21080],
          https: [port: 21443]
        ]
      end

    :prod ->
      defp env_specific_config() do
        [
          http: [transport_options: [max_connections: 1000]],
          https: [transport_options: [max_connections: 1000]],
          cache_static_manifest: "priv/static/cache_manifest.json"
        ]
      end
  end

  @impl SiteEncrypt
  def certification do
    SiteEncrypt.configure(
      client: :native,
      directory_url: with("localhost" <- Erlangelist.Config.ca_url(), do: local_acme_server()),
      domains: [Erlangelist.Config.domain() | extra_domains()],
      emails: [Erlangelist.Config.email()],
      db_folder: Erlangelist.db_path("site_encrypt"),
      backup: Path.join(Erlangelist.Backup.folder(), "site_encrypt.tgz")
    )
  end

  @impl SiteEncrypt
  def handle_new_cert(), do: :ok

  defp local_acme_server,
    do: {:internal, port: unquote(if Mix.env() != :test, do: 20081, else: 21081)}

  defp extra_domains, do: Erlangelist.Config.extra_domains() |> String.split(",") |> Enum.reject(&(&1 == ""))
end
