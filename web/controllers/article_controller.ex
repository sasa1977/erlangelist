defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller

  def last(conn, _params) do
    render_article(conn, hd(articles))
  end

  def post(conn, _params) do
    [title] = conn.path_info

    render_article(conn, article_meta(title))
  end

  defp render_article(conn, meta) do
    conn
    |> render("article.html", %{article: article(meta)})
  end

  defp article_meta(title) do
    Enum.find(articles, fn({t, _}) -> title == t end)
  end

  defp articles do
    {articles_meta, _} = Code.eval_file("#{Application.app_dir(:erlangelist, "priv")}/articles.exs")
    articles_meta
  end

  defp article({title, meta}) do
    [{:html, {:safe, article_html(title)}} | meta]
  end

  defp article_html(title) do
    "#{Application.app_dir(:erlangelist, "priv")}/articles/#{title}.md"
    |> File.read!
    |> Earmark.to_html
  end
end
