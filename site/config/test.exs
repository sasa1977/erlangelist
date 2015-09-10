use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :erlangelist, Erlangelist.Endpoint,
  http: [port: 4001],
  server: false

# No cache expiry
config :erlangelist, :articles_cache, []

# Print only warnings and errors during test
config :logger, level: :warn

# Set a higher stacktrace during test
config :phoenix, :stacktrace_depth, 20
