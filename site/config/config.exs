use Mix.Config

# Configures the endpoint
config :erlangelist, ErlangelistWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "7I7612VkWxb01jyTBpmfY0rXImTfx+tPinUXT3i3Irm8KjANbfVtnYHGYfPJADQw",
  render_errors: [view: ErlangelistWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Erlangelist.PubSub, adapter: Phoenix.PubSub.PG2]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :erlangelist, google_analytics: false

import_config "#{Mix.env()}.exs"
