defmodule Erlangelist.AnalyticsTest do
  use ExUnit.Case

  alias Erlangelist.DbCounter
  alias Erlangelist.Repo
  alias Erlangelist.Model.CountryVisit
  alias Erlangelist.Analytics.Queries

  setup do
    Ecto.Adapters.SQL.query(Repo, "truncate table country_visits", [])
    :ok
  end

  test "db counter" do
    DbCounter.inc(CountryVisit, "foo")
    DbCounter.inc(CountryVisit, "bar")
    DbCounter.inc(CountryVisit, "foo", 3)
    :timer.sleep(10)
    assert [["bar", 1], ["foo", 4]] == db_count
  end

  defp db_count do
    CountryVisit
    |> Queries.count
    |> Repo.all
    |> Enum.sort
  end
end