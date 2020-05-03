defmodule Erlangelist.RssControllerTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  alias Erlangelist.Article
  alias ErlangelistTest.Client

  test "entire feed" do
    response = response(Client.rss_feed(), 200)

    for article <- Article.all(), article.has_content? do
      assert response =~ "<h1>#{Plug.HTML.html_escape(article.long_title)}</h1>"
    end
  end
end
