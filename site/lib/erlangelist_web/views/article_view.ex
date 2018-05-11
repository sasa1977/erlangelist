defmodule ErlangelistWeb.ArticleView do
  use ErlangelistWeb, :view

  def articles_links_html do
    render(ErlangelistWeb.ArticleView, "_articles.html", articles: Erlangelist.Article.all())
  end
end
