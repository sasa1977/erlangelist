defmodule Erlangelist.Analytics do
  require Logger

  alias Erlangelist.Repo
  alias Erlangelist.Analytics.Queries

  def inc(model, increments) do
    for {key, increment} <- increments do
      raw_query(Queries.increment(model, key, increment))
    end
  end

  def all do
    max_visits =
      for model <- Queries.table_sources, into: %{} do
        {model, Repo.all(Queries.count(model))}
      end

    for period <- Queries.periods do
      {
        period,
        for model <- Queries.table_sources do
          {model, visit_data(max_visits, model, period)}
        end
      }
    end
  end

  defp visit_data(max_visits, model, period) do
    counts_base = previous_counts(model, period)

    Stream.map(max_visits[model], fn([key, count]) ->
      past_count = counts_base[key] || 0
      {key, count - past_count}
    end)
    |> Stream.filter(fn({_, count}) -> count > 0 end)
    |> Enum.sort_by(
          fn({name, count}) -> {-count, name} end,
          &<=/2
        )
    |> Enum.take(10)
  end

  defp previous_counts(model, period, key \\ nil)
  defp previous_counts(_model, "all", _key), do: %{}
  defp previous_counts(model, period, key) do
    Queries.previous_counts(model, period, key)
    |> Repo.all
    |> Stream.map(&List.to_tuple/1)
    |> Enum.into(%{})
  end

  def drilldown(model, key, period) do
    previous_count =
      model
      |> previous_counts(period, key)
      |> Map.get(key)
      |> Kernel.||(0)

    Queries.drilldown(model, key, period)
    |> Repo.all
    |> normalize_drilldown_results(previous_count)
  end

  defp normalize_drilldown_results(counts, previous_count) do
    for {[_, previous_count], [ecto_date, count]} <-
      Stream.zip([[nil, previous_count] | counts], counts)
    do
      {:ok, datetime} = Timex.Ecto.DateTime.load(ecto_date)
      {datetime, count - previous_count}
    end
  end

  def compact do
    for model <- Queries.table_sources do
      {:ok, %{num_rows: num_rows}} = raw_query(Queries.compact(model))

      if num_rows > 0 do
        Logger.info("#{model.__schema__(:source)} compacted, deleted #{num_rows} rows")
      end
    end
  end

  defp raw_query({query, params}) do
    Ecto.Adapters.SQL.query(Repo, query, params)
  end
end