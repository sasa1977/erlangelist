defmodule Erlangelist.ArticleControllerTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  alias Erlangelist.Article
  alias ErlangelistTest.Client

  test "http requests are redirected to https" do
    assert redirected_to(Client.get("/some/path", scheme: :http), 301) == "https://localhost/some/path"
  end

  test "root page shows the most recent article" do
    assert response(Client.get("/"), 200) =~ "<h1>#{Plug.HTML.html_escape(Article.most_recent().long_title)}</h1>"
  end

  for article <- Article.all(), article.has_content? do
    test "shows the #{article.id} article" do
      assert response(Client.article(unquote(article.id)), 200) =~
               "<h1>#{Plug.HTML.html_escape(unquote(article.long_title))}</h1>"
    end
  end

  test "renders not found for unknown article" do
    assert response(Client.article("unknown_article"), 404) =~ "Page not found"
  end
end
