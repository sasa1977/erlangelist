defmodule Erlangelist.DbLoggerPlug do
  @behaviour Plug

  require Logger

  alias Erlangelist.GeoIp
  alias Erlangelist.RequestDbLogger

  def init(opts), do: opts

  def call(conn, _config) do
    log(
      conn.request_path,
      conn.remote_ip,
      Plug.Conn.get_req_header(conn, "referer"),
      Plug.Conn.get_req_header(conn, "user-agent")
    )

    conn
  end

  defp log(request_path, remote_ip, referers, user_agents) do
    # We'll compute the data lazily to avoid needless processing during
    # request. This also plays nicely with rate limiting that's
    # done in the RequestDbLogger. If too many requests are made, we
    # avoid needlessly computing data which won't be used.
    RequestDbLogger.log(
      fn ->
        ip = Erlangelist.Helper.ip_string(remote_ip)
        country = country(ip)
        for referer <- pad(referers), user_agent <- pad(user_agents) do
          {request_path, ip, country, referer, user_agent}
        end
      end
    )
  end

  defp pad([]), do: [""]
  defp pad(list), do: list

  defp country(remote_ip) do
    try do
      GeoIp.country(remote_ip)
    catch type, error ->
      # Bypassing "let-it-crash", since this is not critical.
      Logger.error("Error fetching geolocation: #{inspect {type, error, System.stacktrace}}")
      ""
    end
  end
end