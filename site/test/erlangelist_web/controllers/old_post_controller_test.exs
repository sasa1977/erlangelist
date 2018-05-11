defmodule Erlangelist.OldPostControllerTest do
  use ErlangelistWeb.ConnCase
  alias Erlangelist.Article

  for {_article_id, meta} <- Article.all(), meta[:redirect] != nil do
    test_get(meta[:redirect], 302, ~s(<a href="#{meta[:redirect]}">))
  end
end
