defmodule Erlangelist.Web.Dashboard.Telemetry do
  import Telemetry.Metrics

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  @doc false
  def child_spec(_arg) do
    Supervisor.child_spec(
      {:telemetry_poller, measurements: [], period: :timer.seconds(10)},
      id: __MODULE__
    )
  end
end
