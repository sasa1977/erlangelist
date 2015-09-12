# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :lager,
  error_logger_redirect: false,
  error_logger_whitelist: [Logger.ErrorHandler],
  crash_log: false,
  handlers: [{LagerLogger, [level: :info]}]

# Configures the endpoint
config :erlangelist, Erlangelist.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "ija3ahutZFpFyiWJLfLX9uJ1MGVv5knZDT1cxEY+1cbkAdnw3R858Xhdk2lIgxOh",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Erlangelist.PubSub,
           adapter: Phoenix.PubSub.PG2],
  http: [compress: true]

config :erlangelist,
  geoip_site: "127.0.0.1",
  article_event_handlers: [
    Erlangelist.ArticleEvent.Metrics
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :kernel, inet_dist_listen_min: 30000
config :kernel, inet_dist_listen_max: 30000

import_config "exometer.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
