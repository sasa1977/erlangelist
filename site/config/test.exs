use Mix.Config

config :logger, level: :warn

config :erlangelist, ErlangelistWeb.Endpoint, server: false, url: [host: "localhost"]

config :erlangelist, :usage_stats,
  cleanup_interval: :timer.seconds(1),
  flush_interval: :timer.seconds(1),
  retention: 7
