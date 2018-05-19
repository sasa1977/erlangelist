use Mix.Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :erlangelist, ErlangelistWeb.Endpoint, []

import_config "#{Mix.env()}.exs"
