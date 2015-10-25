defmodule Erlangelist.Plug.Logger do
  @behaviour Plug

  require Logger

  def init(opts) do
    Plug.Logger.init(opts)
  end

  def call(conn, level) do
    case Erlangelist.run_limited(:plug_logger, fn -> do_log(conn, level) end) do
      {:ok, new_conn} -> new_conn
      :error -> conn
    end
  end

  defp do_log(conn, level) do
    conn = Plug.Logger.call(conn, level)

    Logger.log level, fn ->
      ["from: ", Erlangelist.Helper.ip_string(conn.remote_ip) || "unknown"]
    end

    conn
  end
end