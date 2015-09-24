defmodule Erlangelist do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Erlangelist.OneOff, []),
      worker(Erlangelist.Repo, [], function: :start_repo),
      worker(ConCache, [app_env!(:articles_cache), [name: :articles_cache]], id: :articles_cache),
      worker(ConCache, [[], [name: :metrics_cache]], id: :metrics_cache),
      worker(ConCache,
        [
          [ttl_check: :timer.minutes(1), ttl: :timer.seconds(30)],
          [name: :geoip_cache]
        ],
        id: :geoip_cache
      ),
      worker(Erlangelist.ArticleEvent, []),
      worker(Erlangelist.RequestDbLogger, []),
      supervisor(Erlangelist.PersistentCounterServer, [], function: :start_sup),
      supervisor(Erlangelist.Endpoint.Site, []),
      supervisor(Erlangelist.Endpoint.Admin, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Erlangelist.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Erlangelist.Endpoint.Site.config_change(changed, removed)
    :ok
  end

  def app_env!(name) do
    {:ok, value} = Application.fetch_env(:erlangelist, name)
    value
  end
end
