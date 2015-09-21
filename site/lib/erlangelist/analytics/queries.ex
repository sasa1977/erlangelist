defmodule Erlangelist.Analytics.Queries do
  @moduledoc false
  require Logger
  import Ecto.Query, only: [from: 2]

  @periods ["recent", "day", "month", "all"]

  def periods, do: @periods

  def table_sources do
    [
      Erlangelist.Model.ArticleVisit,
      Erlangelist.Model.CountryVisit,
      Erlangelist.Model.RefererHostVisit,
      Erlangelist.Model.RefererVisit
    ]
  end

  def count(model) do
    from visit in grouped_visits(model),
    select: [visit.key, max(visit.value)],
    order_by: [desc: max(visit.value)]
  end

  def previous_counts(model, period, key \\ nil) do
    (
      from visit in grouped_visits(model),
      select: [visit.key, max(visit.value)]
    )
    |> filter_before(period)
    |> filter_key(key)
  end

  defp grouped_visits(model) do
    from visit in model,
      group_by: [visit.key]
  end


  partition_points = %{
    "recent" => "2 hour",
    "day" => "1 day",
    "month" => "1 month"
  }
  for period <- @periods do
    if partition_point = partition_points[period] do
      partition_point = "now() at time zone 'utc' - interval '#{partition_point}'"
      defp filter_before(source, unquote(period)) do
        from visit in source,
        where: visit.created_at <= fragment(unquote(partition_point))
      end

      defp filter_after(source, unquote(period)) do
        from visit in source,
        where: visit.created_at > fragment(unquote(partition_point))
      end
    end
  end

  defp filter_after(source, _), do: source

  defp filter_key(source, nil), do: source
  defp filter_key(source, key) do
    from s in source, where: s.key == ^key
  end


  def drilldown(model, key, period) do
    model
    |> filter_key(key)
    |> select(period)
    |> filter_after(period)
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

  defmacrop quantized_time("recent", field), do: quote(do: minute_quant(15, unquote(field)))
  defmacrop quantized_time("day", field), do: quote(do: date_trunc("hour", unquote(field)))
  defmacrop quantized_time("month", field), do: quote(do: date_trunc("day", unquote(field)))
  defmacrop quantized_time("all", field), do: quote(do: date_trunc("month", unquote(field)))

  for period <- @periods do
    query_params = quote do
      [
        select: [quantized_time(unquote(period), s.created_at), max(s.value)],
        group_by: quantized_time(unquote(period), s.created_at),
        order_by: quantized_time(unquote(period), s.created_at)
      ]
    end

    defp select(source, unquote(period)), do: (from s in source, unquote(query_params))
  end


  def increment(model, key, increment) do
    table_name = model.__schema__(:source)
    {
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
    }
  end

  def compact(model) do
    table_name = model.__schema__(:source)
    {
      ~s/
        delete from #{table_name}
        using (
          select key, date(created_at) created_at_date, max(value) max_value
          from #{table_name}
          where date(created_at) < date(now() at time zone 'utc')
          group by key, date(created_at)
        ) newest
        where
          #{table_name}.key=newest.key
          and date(#{table_name}.created_at)=newest.created_at_date
          and #{table_name}.value < newest.max_value
      /
      |> String.replace(~r(\s+), " "),
      []
    }
  end
end