defmodule Erlangelist.ArticleController do
  use Erlangelist.Web, :controller

  def last(conn, _params) do
    render_article(conn, hd(articles))
  end

  def post(conn, %{"article_id" => article_id}) do
    case article_meta(article_id) do
      nil -> render(conn, Erlangelist.ErrorView, "404.html")
      meta -> render_article(conn, meta)
    end
  end

  defp render_article(conn, meta) do
    conn
    |> render("article.html", %{article: article(meta)})
  end

  defp article_meta(article_id) do
    Enum.find(articles, fn({id, _}) -> id == article_id end)
  end

  defp articles do
    ConCache.get_or_store(:articles, :articles_metas, fn ->
      {articles_meta, _} = Code.eval_file("#{Application.app_dir(:erlangelist, "priv")}/articles.exs")
      for {article_id, meta} <- articles_meta do
        {
          article_id,
          Enum.map(meta, fn
            {:posted_at, isodate} ->
              {:ok, date} = Timex.DateFormat.parse(isodate, "{ISOdate}")
              {:ok, formatted_date} = Timex.DateFormat.format(date, "%B %d, %Y", :strftime)
              {:posted_at, formatted_date} |> IO.inspect

            other -> other
          end)
        }
      end
    end)
  end

  defp article({article_id, meta}) do
    ConCache.get_or_store(:articles, {:article, article_id}, fn ->
      [{:html, {:safe, article_html(article_id)}} | meta]
    end)
  end

  defp article_html(article_id) do
    "#{Application.app_dir(:erlangelist, "priv")}/articles/#{article_id}.md"
    |> File.read!
    |> Earmark.to_html
  end
end
