defmodule Erlangelist.ArticleControllerTest do
  use Erlangelist.ConnCase
  alias Erlangelist.Article

  test_get "/", 200, "<h1>#{(Article.most_recent |> Article.meta)[:title]}</h1>"

  test_get "/article/unknown", 404, "Page not found"

  for {article_id, meta} <- Article.all, meta[:redirect] == nil do
    test_get "/article/#{article_id}", 200, "<h1>#{meta[:title]}</h1>"

    if legacy_url = meta[:legacy_url] do
      test_get legacy_url, 200, "<h1>#{meta[:title]}</h1>"
    end
  end
end
