# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :erlangelist, Erlangelist.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "erlangelist_repo",
  username: "user",
  password: "pass",
  hostname: "localhost"


Code.require_file("config/settings.exs")

var!(config, Mix.Config) =
  Enum.reduce(
    Erlangelist.Settings.all,
    var!(config, Mix.Config),
    fn({app, settings}, acc) ->
      var!(config, Mix.Config) = acc
      config(app, settings)
      var!(config, Mix.Config)
    end
  )

import_config "exometer.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
