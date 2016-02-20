# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :phoenix, :format_encoders, html: Phoenix.HTML.Engine

# Configures the endpoint
config :simple_server, SimpleServer.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "QuXk7/9BiA8BBvYylz32Jq7IrGDm9QXdIjWlG4dcK2Aitv7VvtORaxUD32uYg69t",
  render_errors: [accepts: ~w(json)],
  pubsub: [name: SimpleServer.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
