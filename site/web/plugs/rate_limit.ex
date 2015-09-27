defmodule Erlangelist.Plug.RateLimit do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    with = opts[:with]
    values = Enum.map(opts[:for] || [], &Map.get(conn, &1))
    if Erlangelist.rate_limit_allows?(with, {with, values}) do
      conn
    else
      Erlangelist.log_limit_exceeded({with, values})

      conn
      |> Plug.Conn.send_resp(429, "Too many requests from your IP address.")
      |> Plug.Conn.halt
    end
  end
end