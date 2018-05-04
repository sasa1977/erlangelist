use Mix.Config

config :logger, level: :info

config :phoenix, serve_endpoints: true

config :erlangelist, ErlangelistWeb.Endpoint,
  url: [host: "theerlangelist.com", port: 80],
  http: [
    port: 4000,
    max_connections: 1000,
    compress: true
  ],
  cache_static_manifest: "priv/static/cache_manifest.json"
