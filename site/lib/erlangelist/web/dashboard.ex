defmodule Erlangelist.Web.Dashboard do
  def start_link do
    Parent.Supervisor.start_link(
      [
        Erlangelist.Web.Dashboard.Telemetry,
        Erlangelist.Web.Dashboard.Endpoint
      ],
      name: __MODULE__
    )
  end

  @doc false
  def child_spec(_) do
    %{
      id: __MODULE__,
      type: :supervisor,
      start: {__MODULE__, :start_link, []}
    }
  end
end
