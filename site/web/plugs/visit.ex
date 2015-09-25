defmodule Erlangelist.VisitPlug do
  @behaviour Plug

  alias Erlangelist.Metrics

  def init(opts), do: opts

  def call(conn, _config) do
    Metrics.inc_spiral([:site, :requests])
    start_time = :os.timestamp
    Plug.Conn.register_before_send(conn, &before_send(&1, start_time))
  end

  defp before_send(conn, start_time) do
    end_time = :os.timestamp
    diff = :timer.now_diff(end_time, start_time)
    Metrics.sample_histogram([:site, :response_time], diff / 1000)

    conn
  end
end