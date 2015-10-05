defmodule Erlangelist.ArticleEvent do
  alias Erlangelist.Metrics
  alias Erlangelist.GeolocationReporter
  alias Erlangelist.DbCounter
  alias Erlangelist.Model.ArticleVisit
  alias Erlangelist.Model.RefererVisit
  alias Erlangelist.Model.RefererHostVisit

  def visited(article, conn) do
    GeolocationReporter.report(conn.remote_ip)
    DbCounter.inc(ArticleVisit, "all")
    DbCounter.inc(ArticleVisit, article.id)

    for referer <- Plug.Conn.get_req_header(conn, "referer") do
      {host, url} = {URI.parse(referer).host, referer}
      if host, do: DbCounter.inc(RefererHostVisit, host)
      if url, do: DbCounter.inc(RefererVisit, url)
    end
  end

  def invalid_article do
    Metrics.inc_spiral([:article, :invalid_article, :requests])
    DbCounter.inc(ArticleVisit, "invalid_article")
  end
end
