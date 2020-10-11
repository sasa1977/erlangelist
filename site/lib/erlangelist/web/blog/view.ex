defmodule Erlangelist.Web.Blog.View do
  use Phoenix.View,
    root: "lib/erlangelist/web/blog/templates",
    namespace: Erlangelist.Web.Blog

  use Phoenix.HTML
  import Erlangelist.Web.Blog.Router.Helpers

  require Erlangelist.Core.Article
  require Erlangelist.Web.Blog.CodeHighlighter

  alias Erlangelist.Core.Article
  alias Erlangelist.Web.Blog.CodeHighlighter

  for article <- Article.all() do
    def article_html(%{id: unquote(article.id)}) do
      unquote(
        article.content
        |> Earmark.as_html!()
        |> CodeHighlighter.highlight_code_blocks()
      )
    end
  end

  def articles_links_html do
    render("_articles.html", articles: Erlangelist.Core.Article.all())
  end

  def render("404.html", _assigns) do
    {:safe, "<div style='margin-top:20px;'>Page not found</div>"}
  end

  def render("500.html", _assigns) do
    {:safe, "<div style='margin-top:20px;'>Server internal error</div>"}
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
