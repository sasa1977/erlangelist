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

    Client.article(:periodic, accessed_at: yesterday)
    Client.article(:macros_1, accessed_at: yesterday)
    Client.article(:macros_1, accessed_at: yesterday)
    Client.article(:macros_1, accessed_at: yesterday)

    Client.article(:periodic, accessed_at: today)
    Client.article(:periodic, accessed_at: today)
    Client.article(:macros_2, accessed_at: today)

    UsageStats.sync()

    assert UsageStats.all() == %{
             yesterday => %{article: %{periodic: 1, macros_1: 3}},
             today => %{article: %{periodic: 2, macros_2: 1}}
           }
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
