defmodule ErlangelistApp do
  use Application

  def start(_type, _args),
    do: Supervisor.start_link([Erlangelist, ErlangelistWeb], name: __MODULE__, strategy: :one_for_one)

  def config_change(changed, _new, removed) do
    ErlangelistWeb.config_change(changed, removed)
    :ok
  end
end
