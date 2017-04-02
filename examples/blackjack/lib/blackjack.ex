defmodule Blackjack do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children =
      [
        supervisor(Registry, [:unique, Blackjack.Registry]),
        Blackjack.RoundServer.child_spec()
      ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end

  def service_name(service_id), do:
    {:via, Registry, {Blackjack.Registry, service_id}}
end
