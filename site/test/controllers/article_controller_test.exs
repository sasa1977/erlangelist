defmodule Erlangelist.ArticleControllerTest do
  use Erlangelist.ConnCase
  alias Erlangelist.Article

  test "GET /" do
    expected_title = (Article.most_recent |> Article.meta)[:title]
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "<h1>#{expected_title}</h1>"
  end

  test "GET /article/unknown" do
    conn = get(conn, "/article/unknown")
    assert html_response(conn, 404) =~ "Page not found"
  end

  for {article_id, meta} <- Article.all, meta[:redirect] == nil do
    test "GET /article/#{article_id}" do
      conn = get(conn, "/article/#{unquote(article_id)}")
      assert html_response(conn, 200) =~ "<h1>#{unquote(meta[:title])}</h1>"
    end
  end
end
