defmodule Erlangelist.UsageStats.Server do
  use Parent.GenServer
  alias Erlangelist.UsageStats

  def start_link(_), do: Parent.GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def report(key, value), do: GenServer.cast(__MODULE__, {:report, key, value})

  @impl GenServer
  def init(_), do: {:ok, []}

  @impl GenServer
  def handle_cast({:report, key, value}, stats), do: {:noreply, add_report(stats, key, value)}

  @impl Parent.GenServer
  def handle_child_terminated(UsageStats.Writer, _meta, _pid, _reason, stats), do: {:noreply, maybe_start_writer(stats)}

  defp add_report(stats, key, value), do: maybe_start_writer([{key, value} | stats])

  defp maybe_start_writer(stats) do
    if not Parent.GenServer.child?(UsageStats.Writer) and not Enum.empty?(stats) do
      Parent.GenServer.start_child({UsageStats.Writer, stats})
      []
    else
      stats
    end
  end
end
