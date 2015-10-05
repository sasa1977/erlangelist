defmodule Erlangelist.DbCounter do
  require Logger
  use ExActor.GenServer, export: __MODULE__

  alias Erlangelist.Analytics

  def inc(model, label, count \\ 1) do
    key = {model, label}
    :ets.update_counter(__MODULE__, key, count, {key, 0})
  end

  defstart start_link do
    Process.flag(:trap_exit, true)
    :ets.new(
      __MODULE__,
      [:named_table, :public, read_concurrency: true, write_concurrency: true]
    )

    Erlangelist.app_env!(:db_counter_save_interval)
    |> :timer.send_interval(:persist_counts)

    initial_state(nil)
  end

  defhandleinfo :persist_counts do
    store
    noreply
  end

  defhandleinfo _, do: noreply

  def terminate(_, _), do: store

  defp store do
    data = :ets.tab2list(__MODULE__)

    data
    |> Stream.filter(fn({_key, count}) -> count > 0 end)
    |> Enum.map(&Task.async(fn -> update_counter(&1) end))
    |> Enum.each(&Task.await/1)

    for {key, count} <- data do
      case :ets.update_counter(__MODULE__, key, -count) do
        0 -> :ets.delete_object(__MODULE__, {key, 0})
        _other -> :ok
      end
    end
  end

  defp update_counter({{model, label}, count}) do
    # Don't really want to crash here, because it might cause too many
    # restarts and ultimately overload the system. This is a non-critical work,
    # so just log error and resume as normal.
    try do
      Analytics.inc(model, label, count)
    catch
      type, error ->
        Logger.error(inspect({type, error, System.stacktrace}))
    end
  end
end
