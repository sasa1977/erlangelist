defmodule Erlangelist.OldPostControllerTest do
  use Erlangelist.ConnCase
  alias Erlangelist.Article

  for {_article_id, meta} <- Article.all, meta[:redirect] != nil do
    url = String.replace(meta[:redirect], "http://theerlangelist.blogspot.com","")
    test "GET #{url}" do
      conn = get(conn, unquote(url))
      assert html_response(conn, 302) =~ ~s(<a href="#{unquote(meta[:redirect])}">)
    end
  end
end
