defmodule ErlangelistWeb.GeoIP do
  @behaviour Plug

  def data(conn), do: conn.private.geo_ip_data

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _config), do: Plug.Conn.put_private(conn, :geo_ip_data, geo_ip_data(conn))

  defp geo_ip_data(conn) do
    with ip_string when not is_nil(ip_string) <- ip_string(conn.remote_ip),
         {:ok, geoip_data} <- GeoIP.lookup(ip_string),
         country when not is_nil(country) <- geoip_data.country_name do
      Map.take(geoip_data, [:country_code, :country_name])
    else
      _ -> %{country_code: nil, country_name: nil}
    end
  end

  defp ip_string({x, y, z, w}), do: "#{x}.#{y}.#{z}.#{w}"
  defp ip_string(_), do: nil
end
