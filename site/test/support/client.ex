defmodule ErlangelistTest.Client do
  import Phoenix.ConnTest

  @endpoint ErlangelistWeb.Endpoint

  def get(path), do: get(build_conn(), path)

  def article(id, opts \\ []) do
    set_today(Keyword.get(opts, :accessed_at, Date.utc_today()))
    get("/article/#{id}")
  after
    Erlangelist.UsageStats.sync()
  end

  def rss_feed, do: get("/rss")

  def set_today(date) do
    Mox.stub(Erlangelist.Date.Mock, :utc_today, fn -> date end)
    Mox.allow(Erlangelist.Date.Mock, self(), Erlangelist.UsageStats.Server)
    Mox.allow(Erlangelist.Date.Mock, self(), Erlangelist.UsageStats.Cleanup)
  end
end
