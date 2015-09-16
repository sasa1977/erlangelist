defmodule Erlangelist.OldPostController do
  use Erlangelist.Web, :controller

  alias Erlangelist.ArticleEvent

  def render(%{private: %{article: article}} = conn, _params) do
    ArticleEvent.visited(article, conn)
    redirect(conn, external: "http://theerlangelist.blogspot.com#{article.redirect}")
  end
end
