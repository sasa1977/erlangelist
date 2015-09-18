defmodule Erlangelist.VisitPlug do
  @behaviour Plug
  require Logger

  alias Erlangelist.Metrics

  def init(opts), do: opts

  def call(conn, _config) do
    Metrics.inc_spiral([:site, :requests])

    Logger.info([
      conn.method, " ", conn.request_path,
      " remote: ",
      conn.remote_ip
      |> Tuple.to_list
      |> Stream.map(&Integer.to_string/1)
      |> Enum.join(".")
    ])

    start_time = :os.timestamp
    Plug.Conn.register_before_send(conn, &before_send(&1, start_time))
  end

  defp before_send(conn, start_time) do
    end_time = :os.timestamp
    diff = :timer.now_diff(end_time, start_time)

    Logger.info([
      connection_type(conn), ?\s, Integer.to_string(conn.status),
      " in ", formatted_diff(diff)
    ])

    Metrics.sample_histogram([:site, :response_time], diff / 1000)

    conn
  end

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string, "ms"]
  defp formatted_diff(diff), do: [diff |> Integer.to_string, "µs"]

  defp connection_type(%{state: :chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"
end