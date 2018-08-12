defmodule Erlangelist.UsageStats.Writer do
  alias Erlangelist.UsageStats

  @doc false
  def child_spec(stats) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> write!(stats) end]}
    }
  end

  defp write!(stats) do
    date = Date.utc_today()
    data_to_store = Enum.reduce(stats, stored_data(date), fn {key, value}, data -> inc_counter(data, key, value) end)
    File.write!(date_file(date), :erlang.term_to_binary(data_to_store))
    Erlangelist.Backup.backup(UsageStats.folder())
  end

  defp inc_counter(data, key, value) do
    data
    |> Map.put_new(key, %{})
    |> update_in([key], &Map.put_new(&1, value, 0))
    |> update_in([key, value], &(&1 + 1))
  end

  def stored_data(date) do
    try do
      date
      |> date_file()
      |> File.read!()
      |> :erlang.binary_to_term()
    catch
      _, _ -> %{}
    end
  end

  defp date_file(date), do: Path.join(UsageStats.folder(), Date.to_iso8601(date, :basic))
end
