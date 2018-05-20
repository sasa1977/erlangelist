defmodule Erlangelist.Application do
  use Application
  import EnvHelper

  def start(_type, _args) do
    Erlangelist.Backup.resync()

    Supervisor.start_link(
      [
        env_based(prod: nil, else: Erlangelist.AcmeServer),
        Erlangelist.UsageStats,
        {SiteEncrypt.Phoenix, {ErlangelistWeb.Endpoint, ErlangelistWeb.Certbot}}
      ]
      |> Enum.reject(&is_nil/1),
      name: Erlangelist.Supervisor,
      strategy: :one_for_one
    )
  end

  def config_change(changed, _new, removed) do
    ErlangelistWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
