defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller

  alias Erlangelist.Article
  alias Erlangelist.ArticleEvent

  def most_recent(conn, _params) do
    render_article(conn, Article.most_recent)
  end

  def article(conn, %{"article_id" => article_id}) do
    render_article(conn, Article.article(article_id))
  end

  def article(conn, _params), do: render_not_found(conn)

  def article_from_old_path(%{private: %{article: article}} = conn, _params) do
    conn
    |> put_layout(:none)
    |> redirect(external: "/article/#{article.id}")
  end


  defp render_article(conn, %{has_content?: true} = article) do
    ArticleEvent.visited(article, %{remote_ip: remote_ip_string(conn)})
    render(conn, "article.html", %{article: article})
  end

  defp render_article(conn, _), do: render_not_found(conn)

  defp render_not_found(conn) do
    ArticleEvent.invalid_article
    render(put_status(conn, 404), Erlangelist.ErrorView, "404.html")
  end

  defp remote_ip_string(conn) do
    conn.remote_ip
    |> Tuple.to_list
    |> Enum.join(".")
  end
end
