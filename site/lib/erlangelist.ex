defmodule Erlangelist do
  use Application

  require Logger

  import Supervisor.Spec, warn: false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children = limiters_spec ++ [
      worker(Erlangelist.Repo, []),
      worker(
        Erlangelist.Repo, [],
        function: :start_migration, restart: :temporary, id: :repo_migration
      ),
      worker(
        ConCache,
        [app_env!(:articles_cache), [name: :articles_cache]],
        id: :articles_cache
      ),
      worker(ConCache, [[], [name: :metrics_cache]], id: :metrics_cache),
      worker(ConCache,
        [
          [ttl_check: :timer.minutes(1), ttl: :timer.seconds(30)],
          [name: :geoip_cache]
        ],
        id: :geoip_cache
      ),
      worker(Erlangelist.ArticleEvent, []),
      worker(Erlangelist.GeolocationReporter, []),
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

  defp limiters_spec do
    for {limiter_name, interval} <- app_env!(:rate_limiters) do
      worker(
        Erlangelist.RateLimiter,
        [full_limiter_name(limiter_name), interval],
        id: limiter_name
      )
    end
  end

  def run_limited(operation_name, fun) do
    if rate_limit_allows?(operation_name) do
      {:ok, fun.()}
    else
      log_limit_exceeded(operation_name)
      :error
    end
  end

  def rate_limit_allows?(operation_name, operation_id \\ nil) do
    case app_env!(:rate_limited_operations)[operation_name] do
      nil -> true
      {limiter_name, rate} ->
        Erlangelist.RateLimiter.allow?(
          full_limiter_name(limiter_name),
          operation_id || operation_name,
          rate
        )
    end
  end

  def log_limit_exceeded(operation_name) do
    if rate_limit_allows?(:limit_warn_log, {:limit_warn_log, operation_name}) do
      Logger.warn("Rate exceeded for #{inspect operation_name}")
    end
  end

  defp full_limiter_name(limiter_name) do
    :"erlangelist_rate_limiter_#{limiter_name}"
  end
end
