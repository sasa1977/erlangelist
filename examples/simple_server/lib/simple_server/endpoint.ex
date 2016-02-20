defmodule SimpleServer.Endpoint do
  use Phoenix.Endpoint, otp_app: :simple_server

  plug :render

  def render(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, SimpleServer.View.render("index.html"))
  end
end
