defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller

  def post(conn, _params) do
    [article] = conn.path_info

    conn
    |> put_view(Erlangelist.PageView)
    |> render("article.html", %{html: {:safe, article_html(article)}})
  end

  def article_html(article) do
    "#{Application.app_dir(:erlangelist, "priv")}/articles/#{article}.md"
    |> File.read!
    |> Earmark.to_html
  end
end
