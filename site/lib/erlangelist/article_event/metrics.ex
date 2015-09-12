defmodule Erlangelist.ArticleEvent.Metrics do
  use GenEvent

  alias Erlangelist.OneOff
  alias Erlangelist.GeoIp
  alias Erlangelist.Metrics

  def handle_event(:invalid_article, state) do
    OneOff.run(fn ->
      Metrics.inc_spiral([:article, :invalid_article, :requests])
    end)

    {:ok, state}
  end

  def handle_event({:article_visited, article, data}, state) do
    OneOff.run(fn -> GeoIp.report_metric(data[:remote_ip]) end)
    OneOff.run(fn -> Metrics.inc_spiral([:article, article.id, :requests]) end)

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end