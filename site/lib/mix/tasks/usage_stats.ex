defmodule Mix.Tasks.Erlangelist.Core.UsageStats do
  use Boundary, classify_to: Erlangelist.Mix
  use Mix.Task

  # Mix.Task behaviour is not in PLT since Mix is not a runtime dep, so we disable the warning
  @dialyzer :no_undefined_callbacks

  @impl Mix.Task
  def run([site, user]) do
    stats = stats(site, user)
    Enum.each(stats, &print_stats/1)
    print_stats({"Total", aggregate_stats(stats)})
  end

  def run(_other), do: Mix.raise("Usage: mix erlangelist.usage_stats example.com user_name")

  defp aggregate_stats(stats) do
    Enum.reduce(stats, %{}, fn {_date, data}, aggregated ->
      Map.merge(aggregated, data, fn _key, original, override ->
        Map.merge(original, override, fn _key, count1, count2 -> count1 + count2 end)
      end)
    end)
  end

  defp print_stats({title, data}) do
    rows =
      data
      |> Map.get(:article, %{})
      |> Enum.sort_by(fn {_article, count} -> count end, &>=/2)
      |> Enum.map(&Tuple.to_list/1)

    total = rows |> Stream.map(fn [_title, count] -> count end) |> Enum.sum()
    rows_to_print = [[bold("total"), total] | rows] |> Enum.take(10)
    headers = [bold("Article"), bold("Count")]

    TableRex.Table.new(rows_to_print, headers, bold(title))
    |> TableRex.Table.put_column_meta(1, align: :right)
    |> TableRex.Table.render!(vertical_style: :off, title_separator_symbol: nil)
    |> IO.puts()
  end

  defp bold(string), do: "#{IO.ANSI.bright()}#{string}#{IO.ANSI.reset()}"

  defp stats(site, user) do
    conn = connect!(site, user)

    conn
    |> files()
    |> Enum.map(&{&1, read_file(conn, &1)})
  end

  defp connect!(site, user) do
    Application.ensure_all_started(:ssh)

    {:ok, conn} =
      SSHEx.connect(
        ip: site,
        user: user,
        user_dir: Application.app_dir(:erlangelist) |> Path.join("priv/.ssh")
      )

    conn
  end

  defp read_file(conn, file) do
    conn
    |> SSHEx.cmd!("cat #{folder()}/#{file}")
    |> :erlang.binary_to_term()
  end

  defp files(conn) do
    SSHEx.cmd!(conn, "ls -1 #{folder()}")
    |> String.trim()
    |> String.split("\n")
    |> Enum.sort()
  end

  defp folder(), do: "/opt/erlangelist/db/usage_stats"
end
