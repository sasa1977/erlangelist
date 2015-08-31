defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller
  require Logger

  def last(conn, _params) do
    conn
    |> render_result(cached_html(:last, &Erlangelist.Article.most_recent/0, ttl: nil))
  end

  def post(conn, %{"article_id" => article_id}) do
    conn
    |> render_result(cached_html(article_id, fn-> Erlangelist.Article.meta(article_id) end))
  end

  defp cached_html(article_id, fetch_article, opts \\ [ttl: :timer.minutes(30)]) do
    ConCache.get_or_store(:articles, {:article_html, article_id}, fn ->
      Logger.info("Building html for article #{article_id}")

      html = article_html(fetch_article.())
      case opts[:ttl] do
        nil -> html
        ttl ->
          %ConCache.Item{value: html, ttl: opts[:ttl]}
      end
    end)
  end

  defp article_html(nil), do:
    Phoenix.View.render(Erlangelist.ErrorView, "404.html")
  defp article_html(%{redirect: _}), do:
    Phoenix.View.render(Erlangelist.ErrorView, "404.html")
  defp article_html(article), do:
    Phoenix.View.render(Erlangelist.ArticleView, "article.html", %{article: article})

  defp render_result(conn, inner) do
    conn
    |> put_layout(false)
    |> render(Erlangelist.LayoutView, "app.html", %{inner: inner})
  end
end
