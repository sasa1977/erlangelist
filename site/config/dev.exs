use Mix.Config

config :logger, level: :debug, console: [format: "[$level] $message\n"]
config :phoenix, :stacktrace_depth, 20
