defmodule Erlangelist.OldPostController do
  use Erlangelist.Web, :controller

  def render(%{private: %{article: article}} = conn, _params) do
    redirect(conn, external: "http://theerlangelist.blogspot.com#{article.redirect}")
  end
end
