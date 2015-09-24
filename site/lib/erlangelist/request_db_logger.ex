defmodule Erlangelist.RequestDbLogger do
  require Logger
  use Workex

  alias Erlangelist.Analytics

  def log(data_producer) do
    Workex.push(__MODULE__, data_producer)
  end

  # store max 10 entries per 10 seconds
  @max_entries 10
  @throttle_interval :timer.seconds(10)

  def start_link do
    Workex.start_link(
      __MODULE__, nil,
      [max_size: @max_entries],
      [name: __MODULE__]
    )
  end

  def init(_), do: {:ok, nil}

  def handle(data_producers, state) do
    entries =
      data_producers
      |> Enum.map(&Task.async(fn -> try_produce_data(&1) end))
      |> Enum.flat_map(&Task.await/1)

    # Don't really want to crash here, because it might cause too many
    # restarts and ultimately overload the system. This is a non-critical work,
    # so just log error and resume as normal.
    try do
      Analytics.insert_log_entries(entries)
      :timer.sleep(@throttle_interval)
    catch
      type, error ->
        Logger.error(inspect({type, error, System.stacktrace}))
    end

    {:ok, state}
  end

  def handle_message(_, state), do: {:ok, state}

  defp try_produce_data(fun) do
    try do
      fun.()
    catch type, error ->
      Logger.error(inspect({type, error, System.stacktrace}))
      []
    end
  end
end
