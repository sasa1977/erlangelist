defmodule ErlangelistWeb.Dashboard do
  def start_link do
    Parent.Supervisor.start_link(
      [
        ErlangelistWeb.Dashboard.Telemetry,
        ErlangelistWeb.Dashboard.Endpoint
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
