defmodule ErlangelistWeb.EndpointConfig do
  def config(phoenix_defaults) do
    phoenix_defaults
    |> DeepMerge.deep_merge(common_config())
    |> DeepMerge.deep_merge(env_specific_config())
    |> configure_https()
  end

  defp common_config() do
    [
      http: [compress: true, port: 20080],
      render_errors: [view: ErlangelistWeb.ErrorView, accepts: ~w(html json)],
      pubsub: [name: Erlangelist.PubSub, adapter: Phoenix.PubSub.PG2]
    ]
  end

  defp configure_https(config) do
    case ErlangelistWeb.Site.ssl_keys() do
      {:ok, keys} -> DeepMerge.deep_merge(config, https: [compress: true, port: 20443] ++ keys)
      :error -> Keyword.put(config, :https, false)
    end
  end

  case Mix.env() do
    :dev ->
      # need to determine assets path at compile time
      @assets_path Path.expand("../../assets", __DIR__)
      unless File.exists?(@assets_path), do: Mix.raise("Assets not found in #{@assets_path}")

      defp env_specific_config() do
        [
          url: [host: "localhost"],
          http: [acceptors: 5],
          https: [acceptors: 5],
          debug_errors: true,
          check_origin: false,
          watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin", cd: @assets_path]],
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
          http: [max_connections: 1000],
          cache_static_manifest: "priv/static/cache_manifest.json"
        ]
      end
  end
end
