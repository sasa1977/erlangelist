defmodule Erlangelist.AnalyticsTest do
  use ExUnit.Case

  require Erlangelist.Analytics
  require Erlangelist.Analytics.Queries

  alias Erlangelist.Analytics
  alias Erlangelist.Analytics.Queries
  alias Erlangelist.Repo

  setup do
    for model <- Queries.table_sources do
      table_name = model.__schema__(:source)
      Ecto.Adapters.SQL.query(Repo, "truncate table #{table_name}", [])
    end
    :ok
  end

  for period <- ["recent", "day", "month", "all"],
      model <- Queries.table_sources
  do
    @period period
    @model model

    test "#{period}/#{model}" do
      assert count(@model, "bar", @period) == 0

      Analytics.inc(@model, [{"foo", 1}, {"bar", 2}])
      assert count(@model, "foo", @period) == 1
      assert count(@model, "bar", @period) == 2

      Analytics.inc(@model, [{"foo", 1}, {"bar", 2}])
      assert count(@model, "foo", @period) == 2
      assert count(@model, "bar", @period) == 4
    end

    test "drilldown #{period}/#{model}" do
      Analytics.inc(@model, [{"foo", 1}, {"bar", 2}])
      Analytics.inc(@model, [{"foo", 2}, {"bar", 3}])
      assert match?([{_, 5}], Analytics.drilldown(@model, "bar", @period))
    end

    defp count(model, key, period) do
      Analytics.all
      |> Enum.into(%{})
      |> Map.get(period)
      |> Keyword.get(model)
      |> Enum.into(%{})
      |> Map.get(key)
      |> Kernel.||(0)
    end
  end

  test "compact" do
    for model <- Queries.table_sources do
      table_name = model.__schema__(:source)
      Ecto.Adapters.SQL.query(Repo, "truncate table #{table_name}", [])

      for i <- 1..9 do
        Analytics.inc(model, [{"foo", 1}])
        assert match?(
          {:ok, %{num_rows: 1}},
          Ecto.Adapters.SQL.query(
            Repo,
            "
              update #{table_name}
              set created_at=created_at - interval '#{div(9 - i, 3)} day'
              where value=#{i}
            ",
            []
          )
        )
      end

      assert count(model, "foo", "day") == 3
      assert count(model, "foo", "all") == 9

      Analytics.compact
      assert count(model, "foo", "day") == 3
      assert count(model, "foo", "all") == 9

      # Two rows for previous two days + three rows for today
      assert match?(
        {:ok, %{rows: [[5]]}},
        Ecto.Adapters.SQL.query(
          Repo,
          "select count(*) from #{table_name}",
          []
        )
      )
    end
  end
end