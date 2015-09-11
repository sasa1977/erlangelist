defmodule Erlangelist.Exometer.Visit do
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]

  alias Erlangelist.Metrics

  def init(opts), do: opts

  def call(conn, _config) do
    Metrics.inc_spiral([:site, :requests])

    before_time = :os.timestamp

    register_before_send conn, fn conn ->
      after_time = :os.timestamp
      diff = :timer.now_diff(after_time, before_time)
      Metrics.sample_histogram([:site, :response_time], diff/1000)

      conn
    end
  end
end