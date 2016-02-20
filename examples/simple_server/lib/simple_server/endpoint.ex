defmodule SimpleServer.Endpoint do
  use Phoenix.Endpoint, otp_app: :simple_server

  plug :render

  def render(conn, _opts) do
    Plug.Conn.send_resp(conn, 200, "Hello World!")
  end
end
