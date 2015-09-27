defmodule Erlangelist.Plug.Logger do
  @behaviour Plug

  def init(opts) do
    Plug.Logger.init(opts)
  end

  def call(conn, level) do
    case Erlangelist.run_limited(:plug_logger, fn -> Plug.Logger.call(conn, level) end) do
      {:ok, result} -> result
      :error -> conn
    end
  end
end