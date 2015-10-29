defmodule Erlangelist.RequestDbLogger do
  require Logger
  use Workex

  def log(data_producer) do
    Erlangelist.run_limited(
      :request_db_log,
      fn -> Workex.push(__MODULE__, data_producer) end
    )
  end

  def start_link do
    Workex.start_link(__MODULE__, nil, [], [name: __MODULE__])
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
      insert_log_entries(entries)
    catch
      type, error ->
        Logger.error(inspect({type, error, System.stacktrace}))
    end

    {:ok, state, :hibernate}
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

  def insert_log_entries(entries) do
    {placeholders, values} =
      for {values, segment} <- Stream.with_index(entries),
          {value, offset} <- Stream.with_index(Tuple.to_list(values)) do
        {"$#{segment * 5 + offset + 1}", value}
      end
      |> :lists.unzip

    placeholders =
      placeholders
      |> Stream.chunk(5, 5)
      |> Enum.map(&"(#{Enum.join(&1, ",")})")
      |> Enum.join(",")

    {:ok, _} =
      Ecto.Adapters.SQL.query(
        Erlangelist.Repo,
        "
          insert into request_log(path, ip, country, referer, user_agent)
          values #{placeholders}
        "
        |> String.replace(~r(\s+), " "),
        values
      )
  end
end
