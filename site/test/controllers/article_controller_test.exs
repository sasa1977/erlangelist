defmodule Erlangelist.ArticleControllerTest do
  use Erlangelist.ConnCase

  alias Erlangelist.Article
  alias Erlangelist.ArticleEvent
  alias Erlangelist.EventTester

  test_get "/", 200, "<h1>#{Plug.HTML.html_escape(Article.most_recent.long_title)}</h1>"

  test_get "/article/unknown", 404, "Page not found"

  for article <- Article.all, article.has_content? do
    test_get "/article/#{article.id}", 200, "<h1>#{Plug.HTML.html_escape(article.long_title)}</h1>"

    if article.legacy_url do
      test_get article.legacy_url, 302, "<a href=\"/article/#{article.id}\">"
    end
  end

  test "article visited event" do
    article_id = Article.most_recent.id
    EventTester.start_listener(ArticleEvent.manager_name)
    get(conn, "/article/#{article_id}")
    assert_receive(
      {:event,
        {:article_visited,
          %{has_content?: true, id: ^article_id},
          %{remote_ip: "127.0.0.1"}
        }
      }
    )
  end

  test "unknown article event" do
    EventTester.start_listener(ArticleEvent.manager_name)
    get(conn, "/article/unknown")
    assert_receive {:event, :invalid_article}
  end
end
