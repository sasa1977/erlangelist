defmodule Erlangelist.Exometer.Visit do
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]

  def init(opts), do: opts

  def call(conn, _config) do
    :exometer.update([:erlangelist, :site, :requests], 1)
    before_time = :os.timestamp

    register_before_send conn, fn conn ->
      after_time = :os.timestamp
      diff = :timer.now_diff(after_time, before_time)

      :exometer.update([:erlangelist, :site, :response_time], diff / 1000)
      conn
    end
  end
end