defmodule Erlangelist.ArticleEvent.Metrics do
  use GenEvent

  alias Erlangelist.OneOff
  alias Erlangelist.GeoIp
  alias Erlangelist.PersistentCounterServer
  alias Erlangelist.Model.ArticleVisit
  alias Erlangelist.Model.RefererVisit
  alias Erlangelist.Model.RefererHostVisit

  def handle_event(:invalid_article, state) do
    Metrics.inc_spiral([:article, :invalid_article, :requests])
    PersistentCounterServer.inc(ArticleVisit, "invalid_article")
    {:ok, state}
  end

  def handle_event({:article_visited, article, data}, state) do
    OneOff.run(fn -> GeoIp.report_metric(data[:remote_ip]) end)
    PersistentCounterServer.inc(ArticleVisit, ["all", article.id])

    for {host, url} <- (data[:referers] || []) do
      if host, do: PersistentCounterServer.inc(RefererHostVisit, host)
      if url, do: PersistentCounterServer.inc(RefererVisit, url)
    end

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end