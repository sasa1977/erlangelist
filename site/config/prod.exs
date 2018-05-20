use Mix.Config

config :logger, level: :info

config :phoenix, serve_endpoints: true

config :erlangelist, ErlangelistWeb.Endpoint,
  url: [host: "www.theerlangelist.com", port: 80],
  http: [max_connections: 1000],
  cache_static_manifest: "priv/static/cache_manifest.json"
