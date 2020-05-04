defmodule ErlangelistApp do
  use Application

  def start(_type, _args) do
    Erlangelist.Backup.resync()

    Supervisor.start_link([Erlangelist, ErlangelistWeb], name: __MODULE__, strategy: :one_for_one)
  end

  def config_change(changed, _new, removed) do
    ErlangelistWeb.config_change(changed, removed)
    :ok
  end
end
