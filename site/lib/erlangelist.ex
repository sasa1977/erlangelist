defmodule Erlangelist do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(ConCache, [app_env!(:articles_cache), [name: :articles_cache]], id: :articles_cache),
      worker(ConCache, [[], [name: :metrics_cache]], id: :metrics_cache),
      worker(Erlangelist.ArticleEvent, []),
      supervisor(Erlangelist.OneOff, []),
      supervisor(Erlangelist.Endpoint, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Erlangelist.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Erlangelist.Endpoint.config_change(changed, removed)
    :ok
  end

  def app_env!(name) do
    {:ok, value} = Application.fetch_env(:erlangelist, name)
    value
  end
end
