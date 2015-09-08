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
    if Article.exists?(article_id) do
      render(conn, "article.html", %{article_id: article_id})
    else
      render(put_status(conn, 404), Erlangelist.ErrorView, "404.html")
    end
  end
end
