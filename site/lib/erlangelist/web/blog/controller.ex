defmodule Erlangelist.Web.Blog.Controller do
  use Phoenix.Controller, namespace: Erlangelist.Web
  import Plug.Conn
  alias Erlangelist.Core.Article
  alias Erlangelist.Web.Blog.View

  plug :put_layout, {View, "layout.html"}

  def most_recent_article(conn, _params) do
    {:ok, article} = Article.read(:most_recent)
    render_article(conn, article)
  end

  def article(conn, params) do
    with {:ok, article_id} <- Map.fetch(params, "article_id"),
         {:ok, article} <- Article.read(article_id) do
      conn
      |> assign(:title_suffix, article.sidebar_title)
      |> render_article(article)
    else
      _ -> not_found(conn)
    end
  end

  def privacy_policy(conn, _params), do: render(conn, "privacy.html")

  def rss(conn, _params) do
    conn
    |> put_layout(false)
    |> put_resp_content_type("application/xml")
    |> render("rss.xml")
  end

  def not_found(conn, _opts \\ nil) do
    conn
    |> put_view(View)
    |> put_status(404)
    |> render("404.html")
  end

  defp render_article(conn, article), do: render(conn, "article.html", article: article)
end
