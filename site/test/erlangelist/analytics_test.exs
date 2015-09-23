defmodule Erlangelist.AnalyticsTest do
  use ExUnit.Case

  require Erlangelist.Analytics
  require Erlangelist.Analytics.Queries

  alias Erlangelist.Analytics
  alias Erlangelist.Analytics.Queries
  alias Erlangelist.Repo

  setup do
    create_test_data
    :ok
  end

  for model <- Queries.table_sources do
    @model model

    test "#{model}" do
      assert count(@model, "foo", "recent") == 3
      assert count(@model, "foo", "day") == 3
      assert count(@model, "foo", "month") == 9
      assert count(@model, "foo", "all") == 9

      assert count(@model, "bar", "recent") == 30
      assert count(@model, "bar", "day") == 30
      assert count(@model, "bar", "month") == 90
      assert count(@model, "bar", "all") == 90
    end

    test "drilldown #{model}" do
      assert match?([{_, 3}], Analytics.drilldown(@model, "foo", "recent"))
      assert match?([{_, 3}], Analytics.drilldown(@model, "foo", "day"))
      assert match?([{_, 3}, {_, 3}, {_, 3}], Analytics.drilldown(@model, "foo", "month"))
      assert match?([{_, 9}], Analytics.drilldown(@model, "foo", "all"))

      assert match?([{_, 30}], Analytics.drilldown(@model, "bar", "recent"))
      assert match?([{_, 30}], Analytics.drilldown(@model, "bar", "day"))
      assert match?([{_, 30}, {_, 30}, {_, 30}], Analytics.drilldown(@model, "bar", "month"))
      assert match?([{_, 90}], Analytics.drilldown(@model, "bar", "all"))
    end
  end

  test "compact" do
    Analytics.compact
    for model <- Queries.table_sources do
      assert count(model, "foo", "day") == 3
      assert count(model, "foo", "all") == 9

      # Two rows for previous two days + three rows for today
      assert match?(
        {:ok, %{rows: [[10]]}},
        Ecto.Adapters.SQL.query(
          Repo,
          "select count(*) from #{model.__schema__(:source)}",
          []
        )
      )
    end
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

  defp create_test_data do
    for model <- Queries.table_sources do
      table_name = model.__schema__(:source)
      Ecto.Adapters.SQL.query(Repo, "truncate table #{table_name}", [])

      for i <- 1..9 do
        Analytics.inc(model, [{"foo", 1}, {"bar", 10}])

        assert match?(
          {:ok, %{num_rows: 2}},
          Ecto.Adapters.SQL.query(
            Repo,
            "
              update #{table_name}
              set created_at=created_at - interval '#{div(9 - i, 3)} day'
              where value in (#{i}, #{i * 10})
            ",
            []
          )
        )
      end
    end
  end
end