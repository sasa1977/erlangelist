defmodule Erlangelist.ArticleView do
  use Erlangelist.Web, :view

  def articles_links_html do
    ConCache.get_or_store(:articles, :articles_links_html, fn ->
      render(Erlangelist.ArticleView, "_articles.html", articles: Erlangelist.Article.all)
    end)
  end
end
