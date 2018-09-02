defmodule Erlangelist.UsageStats.Server do
  use Parent.GenServer
  alias Erlangelist.UsageStats

  def start_link(_), do: Parent.GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def report(category, subcategory), do: GenServer.cast(__MODULE__, {:report, category, subcategory})

  @impl GenServer
  def init(_), do: {:ok, read_stats()}

  @impl GenServer
  def handle_cast({:report, category, subcategory}, stats),
    do: {:noreply, stats |> inc(category, subcategory) |> maybe_start_writer()}

  @impl Parent.GenServer
  def handle_child_terminated(UsageStats.Writer, changes, _pid, reason, stats) do
    stats = if reason != :normal, do: update_in(stats.changes, &MapSet.union(&1, changes)), else: stats
    {:noreply, maybe_start_writer(clear_old_stats(stats))}
  end

  defp maybe_start_writer(stats) do
    if not Enum.empty?(stats.changes) and not Parent.GenServer.child?(UsageStats.Writer) do
      Parent.GenServer.start_child({UsageStats.Writer, changed_data(stats)})
      %{stats | changes: MapSet.new()}
    else
      stats
    end
  end

  defp read_stats() do
    today = Date.utc_today()
    %{changes: MapSet.new(), data: %{today => UsageStats.Writer.stored_data(today)}}
  end

  defp clear_old_stats(stats) do
    in_memory_dates = MapSet.new(Map.keys(stats.data))
    dates_to_keep = MapSet.put(stats.changes, Date.utc_today())
    dates_to_remove = MapSet.difference(in_memory_dates, dates_to_keep)
    update_in(stats.data, &Map.drop(&1, dates_to_remove))
  end

  defp inc(stats, category, subcategory) do
    today = Date.utc_today()
    %{stats | data: do_inc(stats.data, [today, category, subcategory]), changes: MapSet.put(stats.changes, today)}
  end

  defp changed_data(stats), do: Enum.map(stats.changes, &{&1, Map.fetch!(stats.data, &1)})

  defp do_inc(map, [final_key]), do: map |> Map.put_new(final_key, 0) |> Map.update!(final_key, &(&1 + 1))
  defp do_inc(map, [this_key | other_keys]), do: Map.put(map, this_key, do_inc(Map.get(map, this_key, %{}), other_keys))
end
