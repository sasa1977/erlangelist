use Mix.Config

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :erlangelist, ErlangelistWeb.Endpoint,
  url: [host: "localhost"],
  http: [acceptors: 5],
  https: [acceptors: 5],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin", cd: Path.expand("../assets", __DIR__)]],
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/erlangelist_web/views/.*(ex)$},
      ~r{lib/erlangelist_web/templates/.*(eex)$}
    ]
  ]

config :erlangelist, :usage_stats,
  cleanup_interval: :timer.seconds(1),
  flush_interval: :timer.seconds(1),
  retention: 7
