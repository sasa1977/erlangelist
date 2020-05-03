defmodule ErlangelistTest.Client do
  import Phoenix.ConnTest

  @endpoint ErlangelistWeb.Endpoint

  def get(path), do: get(build_conn(), path)

  def article(id), do: get("/article/#{id}")

  def rss_feed, do: get("/rss")
end
