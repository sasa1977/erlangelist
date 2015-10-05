defmodule Erlangelist.ArticleEvent.Metrics do
  use GenEvent

  alias Erlangelist.Metrics
  alias Erlangelist.GeolocationReporter
  alias Erlangelist.PersistentCounterServer
  alias Erlangelist.Model.ArticleVisit
  alias Erlangelist.Model.RefererVisit
  alias Erlangelist.Model.RefererHostVisit

  def handle_event(:invalid_article, state) do
    Metrics.inc_spiral([:article, :invalid_article, :requests])
    PersistentCounterServer.inc(ArticleVisit, "invalid_article")
    {:ok, state}
  end

  def handle_event({:article_visited, article, %{referer: referer, remote_ip: remote_ip}}, state) do
    GeolocationReporter.report(remote_ip)
    PersistentCounterServer.inc(ArticleVisit, "all")
    PersistentCounterServer.inc(ArticleVisit, article.id)

    for referer <- referer do
      {host, url} = {URI.parse(referer).host, referer}
      if host, do: PersistentCounterServer.inc(RefererHostVisit, host)
      if url, do: PersistentCounterServer.inc(RefererVisit, url)
    end

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end