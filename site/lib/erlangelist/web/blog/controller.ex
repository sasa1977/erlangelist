defmodule Erlangelist.Web.Blog.Controller do
  use Phoenix.Controller, namespace: Erlangelist.Web
  import Plug.Conn
  alias Erlangelist.Core.Article
  alias Erlangelist.Web.Blog.View

  plug :put_layout, {View, "layout.html"}

  def most_recent_article(conn, _params) do
    render_article(conn, Article.most_recent())
  end

  def article(conn, %{"article_id" => article_id}) do
    case Article.article(Article.id_from_string(article_id)) do
      nil ->
        not_found(conn)

      article ->
        conn
        |> assign(:title_suffix, article.sidebar_title)
        |> render_article(article)
    end
  end

  def article(conn, _params), do: not_found(conn)

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

  defp render_article(conn, article) do
    Erlangelist.Core.UsageStats.report(:article, article.id)
    render(conn, "article.html", %{article: article})
  end
end
