defmodule Erlangelist.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        Erlangelist.UsageStats,
        ErlangelistWeb.Endpoint
      ],
      name: Erlangelist.Supervisor,
      strategy: :one_for_one
    )
  end

  def config_change(changed, _new, removed) do
    ErlangelistWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
