defmodule Erlangelist.RssController do
  use Erlangelist.Web, :controller

  def index(conn, _params) do
    conn
    |> put_layout(:none)
    |> put_resp_content_type("application/xml")
    |> render "index.xml"
  end
end
