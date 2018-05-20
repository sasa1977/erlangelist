use Mix.Config

config :logger, level: :warn

config :erlangelist, ErlangelistWeb.Endpoint, server: false, url: [host: "localhost"]
