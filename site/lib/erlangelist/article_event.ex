defmodule Erlangelist.ArticleEvent do
  alias Erlangelist.Metrics
  alias Erlangelist.GeolocationReporter
  alias Erlangelist.PersistentCounterServer
  alias Erlangelist.Model.ArticleVisit
  alias Erlangelist.Model.RefererVisit
  alias Erlangelist.Model.RefererHostVisit

  def visited(article, conn) do
    GeolocationReporter.report(conn.remote_ip)
    PersistentCounterServer.inc(ArticleVisit, "all")
    PersistentCounterServer.inc(ArticleVisit, article.id)

    for referer <- Plug.Conn.get_req_header(conn, "referer") do
      {host, url} = {URI.parse(referer).host, referer}
      if host, do: PersistentCounterServer.inc(RefererHostVisit, host)
      if url, do: PersistentCounterServer.inc(RefererVisit, url)
    end
  end

  def invalid_article do
    Metrics.inc_spiral([:article, :invalid_article, :requests])
    PersistentCounterServer.inc(ArticleVisit, "invalid_article")
  end
end
