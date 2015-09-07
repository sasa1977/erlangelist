defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller
  alias Erlangelist.Article


  def most_recent(conn, _params) do
    render_article(conn, Article.most_recent)
  end

  def article(conn, %{"article_id" => article_id}) do
    render_article(conn, article_id)
  end

  defp render_article(conn, article_id) do
    render_article(conn, Article.meta(article_id), Article.html(article_id))
  end

  defp render_article(conn, nil, _), do:
    render(put_status(conn, 404), Erlangelist.ErrorView, "404.html")

  defp render_article(conn, _, nil), do:
    render(put_status(conn, 404), Erlangelist.ErrorView, "404.html")

  defp render_article(conn, meta, html), do:
    render(conn, "article.html", %{meta: meta, html: html})
end
