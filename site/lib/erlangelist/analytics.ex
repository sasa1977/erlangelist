defmodule Erlangelist.Analytics do
  require Logger
  import Ecto.Query, only: [from: 2]

  alias Erlangelist.Repo
  alias Erlangelist.Model.ArticleVisit
  alias Erlangelist.Model.CountryVisit
  alias Erlangelist.Model.RefererHostVisit
  alias Erlangelist.Model.RefererVisit

  periods = ["recent", "day", "month", "all"]

  def inc(model, increments) do
    table_name = model.__schema__(:source)

    for {key, increment} <- increments do
      Ecto.Adapters.SQL.query(
        Repo,
        ~s/
          insert into #{table_name} (key, value) (
            select $1, inc + coalesce(previous.value, 0)
            from
              (select #{increment} inc) increment
              left join (
                select value
                from #{table_name}
                where key=$1
                order by id desc
                limit 1
              ) previous on true
          )
        /
        |> String.replace(~r(\s+), " "),
        [key]
      )
    end
  end

  defp table_sources do
    [
      article: ArticleVisit,
      country: CountryVisit,
      referer_host: RefererHostVisit,
      referer_url: RefererVisit
    ]
  end

  def all do
    max_visits =
      for {_, model} <- table_sources, into: %{} do
        {
          model,
          Repo.all(
            from visit in grouped_visits(model),
            select: [visit.key, max(visit.value)],
            order_by: [desc: max(visit.value)]
          )
        }
      end

    for period <- unquote(periods) do
      {
        period,
        for {visit_type, model} <- table_sources do
          {visit_type, visit_data(max_visits, model, period)}
        end
      }
    end
  end

  defp previous_counts(model, period, key \\ nil)
  defp previous_counts(_model, "all", _key), do: %{}
  defp previous_counts(model, period, key) do
    (
      from visit in grouped_visits(model),
      select: [visit.key, max(visit.value)],
      where: visit.created_at < ^partition_point(period)
    )
    |> maybe_filter_by_key(key)
    |> Repo.all
    |> Stream.map(&List.to_tuple/1)
    |> Enum.into(%{})
  end

  defp maybe_filter_by_key(source, nil), do: source
  defp maybe_filter_by_key(source, key), do: (from visit in source, where: visit.key == ^key)

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

  defp grouped_visits(model) do
    from visit in model,
      group_by: [visit.key]
  end

  defp output_formats do
    %{
      "recent" => "%H:%M",
      "day" => "%d.%m. %H:%M",
      "month" => "%d.%m.",
      "all" => "%b %Y"
    }
  end

  def drilldown(type, key, period) do
    source = table_sources[type]

    source
    |> filter_key(key)
    |> select(period)
    |> Repo.all
    |> normalize_counts(previous_counts(source, period, key)[key] || 0, period)
  end

  defp normalize_counts(counts, previous_count, period) do
    for {[_, previous_count], [ecto_date, count]} <-
      Stream.zip([[nil, previous_count] | counts], counts)
    do
      {:ok, datetime} = Timex.Ecto.DateTime.load(ecto_date)

      {
        Timex.DateFormat.format!(datetime, output_formats[period], :strftime),
        count - previous_count
      }
    end
  end

  defp filter_key(source, key) do
    from s in source, where: s.key == ^key
  end


  defmacrop date_trunc(unit, field) do
    quote do
      fragment(unquote("date_trunc('#{unit}', ?)"), unquote(field))
    end
  end

  defmacrop minute_quant(interval, field) do
    quote do
      fragment(
        unquote(
        "date_trunc('hour', ?) + INTERVAL '#{interval} min' * TRUNC(date_part('minute', ?) / #{interval}.0)"
        ),
        unquote(field), unquote(field)
      )
    end
  end

  defp partition_point("recent"), do: shift_now([hours: -2])
  defp partition_point("day"), do: shift_now([days: -1])
  defp partition_point("month"), do: shift_now([months: -1])

  defmacrop quantized_time("recent", field), do: quote(do: minute_quant(15, unquote(field)))
  defmacrop quantized_time("day", field), do: quote(do: date_trunc("hour", unquote(field)))
  defmacrop quantized_time("month", field), do: quote(do: date_trunc("day", unquote(field)))
  defmacrop quantized_time("all", field), do: quote(do: date_trunc("month", unquote(field)))

  for period <- periods do
    query_params = quote do
      [
        select: [quantized_time(unquote(period), s.created_at), max(s.value)],
        group_by: quantized_time(unquote(period), s.created_at),
        order_by: quantized_time(unquote(period), s.created_at)
      ]
    end

    query_params =
      if period == "all" do
        query_params
      else
        [quote(do: ({:where, s.created_at > ^partition_point(unquote(period))})) | query_params]
      end

    defp select(source, unquote(period)), do: (from s in source, unquote(query_params))
  end

  defp shift_now(span) do
    Timex.Date.now
    |> Timex.Date.shift(span)
    |> dump!
  end

  defp dump!(dt) do
    {:ok, result} = Timex.Ecto.DateTime.dump(dt)
    result
  end


  def compact do
    for {_, model} <- table_sources do
      table_name = model.__schema__(:source)

      {:ok, %{num_rows: num_rows}} = Ecto.Adapters.SQL.query(
        Repo,
        ~s{
          delete from #{table_name}
          using (
            select key, date(created_at) created_at_date, max(value) max_value
            from #{table_name}
            where date(created_at) < date(now())
            group by key, date(created_at)
          ) newest
          where
            #{table_name}.key=newest.key
            and date(#{table_name}.created_at)=newest.created_at_date
            and #{table_name}.value < newest.max_value
        },
        []
      )

      if num_rows > 0 do
        Logger.info("#{table_name} compacted, deleted #{num_rows} rows")
      end
    end
  end
end