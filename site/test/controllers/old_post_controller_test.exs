defmodule Erlangelist.OldPostControllerTest do
  use Erlangelist.ConnCase
  alias Erlangelist.Article

  for {_article_id, meta} <- Article.all, meta[:redirect] != nil do
    String.replace(meta[:redirect], "http://theerlangelist.blogspot.com","")
    |> test_get 302, ~s(<a href="#{meta[:redirect]}">)
  end
end
