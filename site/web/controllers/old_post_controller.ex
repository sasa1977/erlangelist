defmodule Erlangelist.OldPostController do
  use Erlangelist.Web, :controller

  def render(conn, _params) do
    redirect(conn, external: "http://theerlangelist.blogspot.com#{conn.request_path}")
  end
end
