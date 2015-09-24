defmodule Erlangelist.ArticleEvent.Metrics do
  use GenEvent

  alias Erlangelist.OneOff
  alias Erlangelist.GeoIp
  alias Erlangelist.Metrics
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
    report_geoip_metric(data[:remote_ip])
    PersistentCounterServer.inc(ArticleVisit, ["all", article.id])

    for referer <- data[:referer] do
      {host, url} = {URI.parse(referer).host, referer}
      if host, do: PersistentCounterServer.inc(RefererHostVisit, host)
      if url, do: PersistentCounterServer.inc(RefererVisit, url)
    end

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  defp report_geoip_metric(remote_ip) do
    OneOff.run(fn ->
      remote_ip
      |> Erlangelist.Helper.ip_string
      |> GeoIp.country
      |> case do
            nil -> :ok
            "" -> :ok
            country when is_binary(country) ->
              PersistentCounterServer.inc(CountryVisit, country)
          end
    end)
  end
end