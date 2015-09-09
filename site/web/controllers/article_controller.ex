defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller
  alias Erlangelist.Article


  def most_recent(conn, _params) do
    render_article(conn, Article.most_recent)
  end

  def article(conn, %{"article_id" => article_id}) do
    render_article(conn, article_id)
  end

  def article(%{private: %{article_id: article_id}} = conn, _params) do
    render_article(conn, article_id)
  end

  def article(conn, _params) do
    render_not_found(conn)
  end

  defp render_article(conn, article_id) do
    if Article.exists?(article_id) do
      render(conn, "article.html", %{article_id: article_id})
    else
      render_not_found(conn)
    end
  end

  defp render_not_found(conn), do: render(put_status(conn, 404), Erlangelist.ErrorView, "404.html")
end
