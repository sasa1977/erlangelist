defmodule Erlangelist.UsageStats do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def report(key, value), do: GenServer.cast(__MODULE__, {:report, Date.utc_today(), key, value})

  @impl GenServer
  def init(_) do
    File.mkdir_p(db_path())
    enqueue_flush()
    {:ok, initialize_state(Date.utc_today())}
  end

  @impl GenServer
  def handle_cast({:report, date, key, value}, state), do: {:noreply, store_report(state, date, key, value)}

  @impl GenServer
  def handle_info(:flush, state) do
    write_data(state)
    enqueue_flush()
    {:noreply, state}
  end

  def handle_info(other, state), do: super(other, state)

  defp enqueue_flush(), do: Process.send_after(self(), :flush, :timer.seconds(10))

  defp store_report(state, date, key, value) do
    state
    |> ensure_proper_data(date)
    |> update_in([:data], fn data ->
      data
      |> Map.put_new(date, %{})
      |> update_in([date], &Map.put_new(&1, key, %{}))
      |> update_in([date, key], &Map.put_new(&1, value, 0))
      |> update_in([date, key, value], &(&1 + 1))
    end)
  end

  defp ensure_proper_data(%{date: date} = state, date), do: state

  defp ensure_proper_data(state, date) do
    write_data(state)
    initialize_state(date)
  end

  defp initialize_state(date), do: %{date: date, data: read_data(date)}

  defp read_data(date) do
    try do
      date
      |> date_file()
      |> File.read!()
      |> :erlang.binary_to_term()
    catch
      _, _ -> %{}
    end
  end

  defp write_data(state), do: File.write(date_file(state.date), :erlang.term_to_binary(state.data))

  defp db_path(), do: Path.join(Application.app_dir(:erlangelist, "priv"), "db")

  defp date_file(date), do: Path.join(db_path(), Date.to_iso8601(date, :basic))
end
