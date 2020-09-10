defmodule ErlangelistApp do
  use Application

  def start(_type, _args),
    do: Parent.Supervisor.start_link([Erlangelist, ErlangelistWeb], name: __MODULE__)

  def config_change(changed, _new, removed) do
    ErlangelistWeb.config_change(changed, removed)
    :ok
  end
end
