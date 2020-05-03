defmodule Erlangelist.UsageStatsTest do
  use ExUnit.Case, async: false
  alias Erlangelist.UsageStats
  alias ErlangelistTest.Client

  setup do
    UsageStats.clear_all()
  end

  test "aggregates daily stats" do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    desired_stats = %{
      yesterday => %{article: %{periodic: 1, macros_1: 3}},
      today => %{article: %{periodic: 2, why_elixir: 1}}
    }

    for {date, %{article: articles}} <- desired_stats,
        {article, count} <- articles,
        _ <- 1..count,
        do: Client.article(article, accessed_at: date)

    UsageStats.sync()

    assert UsageStats.all() == desired_stats
  end

  test "periodically cleans up old stats" do
    today = Date.utc_today()

    Client.article(:periodic, accessed_at: Date.add(today, -8))
    Client.article(:macros_1, accessed_at: Date.add(today, -7))
    Client.article(:why_elixir, accessed_at: Date.add(today, -6))

    UsageStats.sync()

    ErlangelistTest.Client.set_today(today)
    Periodic.Test.sync_tick(UsageStats.Cleanup)

    assert UsageStats.all() == %{Date.add(today, -6) => %{article: %{why_elixir: 1}}}
  end
end
