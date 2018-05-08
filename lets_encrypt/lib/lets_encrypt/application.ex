defmodule LetsEncrypt.Application do
  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [LetsEncrypt.Registry],
      strategy: :one_for_one,
      name: LetsEncrypt.Supervisor
    )
  end
end
