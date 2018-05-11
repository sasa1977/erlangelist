defmodule ErlangelistWeb.MovePermanently do
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts |> Keyword.take([:from, :to]) |> Map.new()

  @impl Plug
  def call(conn, opts) do
    if conn.host == opts.from do
      url = "#{conn.scheme}://#{opts.to}#{conn.request_path}"
      body = "<html><body>The document has moved <a href=\"#{url}\">here</a>.</body></html>"

      conn
      |> Plug.Conn.put_resp_header("location", url)
      |> Plug.Conn.send_resp(:moved_permanently, body)
      |> Plug.Conn.halt()
    else
      conn
    end
  end
end
