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
    catch type, error ->
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

  defp insert_log_entries([]), do: :ok
  defp insert_log_entries([first_entry | _] = entries) do
    num_values = tuple_size(first_entry)
    {placeholders, values} =
      for {values, segment} <- Stream.with_index(entries),
          {value, offset} <- Stream.with_index(Tuple.to_list(values)) do
        {"$#{segment * num_values + offset + 1}", value}
      end
      |> :lists.unzip

    placeholders =
      placeholders
      |> Stream.chunk(num_values, num_values)
      |> Enum.map(&"(#{Enum.join(&1, ",")})")
      |> Enum.join(",")

    exec_sql!(
      "INSERT INTO request_log(path, ip, country, referer, user_agent) VALUES #{placeholders}",
      values)

    :gproc.lookup_pids({:p, :l, __MODULE__})
    |> Enum.each(&send(&1, :inserted))
  end

  def archive_logs do
    Erlangelist.Repo.transaction(fn ->
      exec_sql!("DELETE FROM request_log_archive WHERE created_at <= current_date - interval '6 months'")

      exec_sql!("SELECT max(id) FROM request_log WHERE created_at <= current_date - interval '7 days'")
      |> transfer_log_rows
    end)

    exec_sql!("VACUUM ANALYZE")

    :ok
  end

  defp transfer_log_rows(%{rows: [[nil]]}), do: :ok
  defp transfer_log_rows(%{rows: [[id]]}) do
    exec_sql!("INSERT INTO request_log_archive SELECT * FROM request_log WHERE id <= $1", [id])
    %{num_rows: num_rows} = exec_sql!("DELETE FROM request_log WHERE id <= $1", [id])
    Logger.info("Archived #{num_rows} log entries")
  end

  defp exec_sql!(sql, params \\ []) do
    {:ok, result} = Ecto.Adapters.SQL.query(
      Erlangelist.Repo,
      String.replace(sql, ~r(\s+), " "),
      params
    )

    result
  end
end
