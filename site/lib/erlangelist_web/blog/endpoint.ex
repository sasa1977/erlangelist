defmodule ErlangelistWeb.Blog.Endpoint do
  require Erlangelist.Config

  use Phoenix.Endpoint, otp_app: :erlangelist

  plug Plug.Static, at: "/", from: :erlangelist, gzip: false, only: ~w(css fonts images js favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.Logger, log: :debug
  plug SiteEncrypt.AcmeChallenge, ErlangelistWeb.Blog.SSL

  plug ErlangelistWeb.Plug.ForceSSL, endpoint: __MODULE__, port: Erlangelist.Config.blog_ssl_port()

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head

  plug ErlangelistWeb.Plug.MovePermanently, from: "theerlangelist.com", to: "www.theerlangelist.com"

  plug ErlangelistWeb.Blog.Router

  def init(_key, phoenix_defaults), do: {:ok, settings(phoenix_defaults)}

  defp settings(phoenix_defaults) do
    phoenix_defaults
    |> DeepMerge.deep_merge(common_config())
    |> DeepMerge.deep_merge(env_specific_config())
  end

  defp common_config() do
    [
      http: [compress: true, port: 20080],
      https: [compress: true, port: 20443] ++ ErlangelistWeb.Blog.SSL.keys(),
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
          url: [host: "localhost"],
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
      defp env_specific_config(), do: [url: [host: "localhost"], server: false]

    :prod ->
      defp env_specific_config() do
        [
          url: [host: "www.theerlangelist.com", port: 80],
          http: [transport_options: [max_connections: 1000]],
          https: [transport_options: [max_connections: 1000]],
          cache_static_manifest: "priv/static/cache_manifest.json"
        ]
      end
  end
end
