defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller

  alias Erlangelist.Article
  alias Erlangelist.Metrics

  def most_recent(conn, _params) do
    render_article(conn, Article.most_recent)
  end

  def article(conn, %{"article_id" => article_id}) do
    case Article.article(Article.id_from_string(article_id)) do
      %{has_content?: true} = article ->
        conn
        |> assign(:title_suffix, article.short_title)
        |> render_article(article)
      _ ->
        not_found(conn)
    end
  end

  def article(conn, _params) do
    Metrics.inc_spiral([:article, :invalid_article, :requests])
    not_found(conn)
  end

  def article_from_old_path(%{private: %{article: article}} = conn, _params) do
    conn
    |> put_layout(:none)
    |> redirect(external: "/article/#{article.id}")
  end


  defp render_article(conn, article) do
    render(conn, "article.html", %{article: article, cookies: conn.cookies["cookies"]})
  end

  def comments(conn, %{"article_id" => article_id}) do
    conn
    |> put_layout(false)
    |> render("_comments.html",
          article: Article.article(Article.id_from_string(article_id)),
          cookies: true
        )
  end


  def not_found(conn, _opts \\ nil) do
    render(put_status(conn, 404), Erlangelist.ErrorView, "404.html")
  end
end
