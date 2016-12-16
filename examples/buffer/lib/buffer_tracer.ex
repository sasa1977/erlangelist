defmodule BufferTracer do
  use GenServer

  def start_link(target_pid), do: GenServer.start_link(__MODULE__, target_pid)

  def stats(tracer_pid), do: GenServer.call(tracer_pid, :stats)

  def stop(tracer_pid), do: GenServer.stop(tracer_pid)

  def init(target_pid) do
    :erlang.trace(target_pid, true, [:receive, :send, :garbage_collection, :monotonic_timestamp])
    {:ok, %{times: :ets.new(:times, [:duplicate_bag]), assigns: %{}}}
  end

  def handle_call(:stats, _from, state) do
    percentiles = [99, 99.9, 99.99, 99.999, 100]

    result =
      for key <- [:"push/pull", :gc] do
        times = Enum.sort(List.flatten(:ets.match(state.times, {key, :"$1"})))
        count = length(times)
        {key, %{
          percentiles: Enum.zip(percentiles, percentiles(times, Enum.map(percentiles, &(&1 / 100)))),
          count: count,
          avg: round(Enum.sum(times) / count),
          worst_10:
            times
            |> Enum.reverse()
            |> Enum.take(10)
            |> Enum.reverse()
        }}
      end
    {:reply, result, state}
  end

  def handle_info({:trace_ts, _pid, :gc_minor_start, _info, time}, state), do:
    {:noreply, assign(state, :gc_minor_start, time)}
  def handle_info({:trace_ts, _pid, :gc_major_start, _info, time}, state), do:
    {:noreply, assign(state, :gc_major_start, time)}
  def handle_info({:trace_ts, _pid, :gc_minor_end, _info, time}, state) do
    :ets.insert(state.times, {:gc, round((time - state.assigns.gc_minor_start) / 1000)})
    {:noreply, state}
  end
  def handle_info({:trace_ts, _pid, :gc_major_end, _info, time}, state) do
    :ets.insert(state.times, {:gc, round((time - state.assigns.gc_major_start) / 1000)})
    {:noreply, state}
  end
  def handle_info({:trace_ts, _pid, :receive, {:"$gen_call", from, {:push, _msg}}, time}, state), do:
    {:noreply, assign(state, from, time)}
  def handle_info({:trace_ts, _pid, :receive, {:"$gen_call", from,:pull}, time}, state), do:
    {:noreply, assign(state, from, time)}
  def handle_info({:trace_ts, _pid, :send, msg, to, time}, state) do
    with {ref, _response} <- msg,
         {:ok, start_time} <- Map.fetch(state.assigns, {to, ref}) do
      :ets.insert(state.times, {:"push/pull", round((time - start_time) / 1000)})
      {:noreply, update_in(state.assigns, &Map.delete(&1, {to, ref}))}
    else
      _ -> {:noreply, state}
    end
  end

  defp assign(state, key, value), do:
    put_in(state, [:assigns, key], value)

  defp percentiles(sorted_series, percentiles) do
    indexed =
      sorted_series
      |> Stream.with_index()
      |> Enum.map(fn({value, index}) -> {index, value} end)
      |> Enum.into(%{})

    percentiles
    |> Enum.map(&min(trunc(Float.ceil(Map.size(indexed) * &1)), Map.size(indexed) - 1))
    |> Enum.map(&Map.fetch!(indexed, &1))
  end
end
