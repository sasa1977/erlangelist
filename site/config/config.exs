use Mix.Config

config :logger, :console,
  format: "$time $metadata[$level] $metadata $message\n",
  metadata: [:user_id, :periodic_job]

config :phoenix, :json_library, Jason

config :erlangelist, Erlangelist.Web.Blog.Endpoint, []
config :erlangelist, Erlangelist.Web.Dashboard.Endpoint, []

if Mix.env() == :dev do
  config :logger, level: :debug, console: [format: "[$level] $metadata $message\n"]
  config :phoenix, :stacktrace_depth, 20

  # code_reloader works only if provided in app env, not in `init/2`
  config :erlangelist, Erlangelist.Web.Blog.Endpoint, code_reloader: true, debug_errors: true
end

if Mix.env() == :prod do
  config :logger, level: :info
  config :phoenix, serve_endpoints: true
end

if Mix.env() == :test do
  config :logger, level: :warn
end
