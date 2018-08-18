defmodule Erlangelist.UsageStats.Writer do
  alias Erlangelist.UsageStats

  @doc false
  def child_spec(stats) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> write!(stats) end]},
      meta: stats |> Enum.map(fn {date, _data} -> date end) |> MapSet.new()
    }
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

  defp write!(stats) do
    Enum.each(stats, fn {date, data} -> File.write!(date_file(date), :erlang.term_to_binary(data)) end)

    Erlangelist.Backup.backup(UsageStats.folder())
  end

  defp date_file(date), do: Path.join(UsageStats.folder(), Date.to_iso8601(date, :basic))
end
