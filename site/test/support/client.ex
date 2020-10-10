defmodule ErlangelistTest.Client do
  require Phoenix.ConnTest
  @endpoint ErlangelistWeb.Blog.Endpoint

  def get(path, opts \\ []) do
    uri =
      path
      |> URI.parse()
      |> Map.update!(:host, &(&1 || "localhost"))
      |> Map.update!(:scheme, &(&1 || "https"))
      |> URI.to_string()

    Erlangelist.Core.UsageStats.mock_today(Keyword.get(opts, :accessed_at, Date.utc_today()))
    Phoenix.ConnTest.get(Phoenix.ConnTest.build_conn(), uri)
  end

  def article(id, opts \\ []) do
    get("/article/#{id}", opts)
  after
    Erlangelist.Core.UsageStats.sync()
  end

  def rss_feed, do: get("/rss")
end
