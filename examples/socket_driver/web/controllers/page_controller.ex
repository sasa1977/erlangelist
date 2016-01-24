defmodule SocketDriver.PageController do
  use SocketDriver.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
