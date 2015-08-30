defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller

  def last(conn, _params) do
    render_article(conn, Erlangelist.Article.most_recent)
  end

  def post(conn, %{"article_id" => article_id}) do
    render_article(conn, Erlangelist.Article.meta(article_id))
  end

  defp render_article(conn, nil), do: render(conn, Erlangelist.ErrorView, "404.html")
  defp render_article(conn, %{redirect: redirect}), do: redirect(conn, external: redirect)
  defp render_article(conn, article), do: render(conn, "article.html", %{article: article})
end
