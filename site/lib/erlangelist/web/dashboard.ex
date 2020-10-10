defmodule Erlangelist.Web.Dashboard do
  use Parent.Supervisor

  def start_link(_) do
    Parent.Supervisor.start_link(
      [
        Erlangelist.Web.Dashboard.Telemetry,
        Erlangelist.Web.Dashboard.Endpoint
      ],
      name: __MODULE__
    )
  end
end
