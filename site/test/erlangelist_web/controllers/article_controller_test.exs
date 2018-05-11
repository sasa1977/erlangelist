defmodule Erlangelist.ArticleControllerTest do
  use ErlangelistWeb.ConnCase
  alias Erlangelist.Article

  test_get("/", 200, "<h1>#{Plug.HTML.html_escape(Article.most_recent().long_title)}</h1>")

  test_get("/article/unknown", 404, "Page not found")

  for article <- Article.all(), article.has_content? do
    test_get("/article/#{article.id}", 200, "<h1>#{Plug.HTML.html_escape(article.long_title)}</h1>")
  end
end
