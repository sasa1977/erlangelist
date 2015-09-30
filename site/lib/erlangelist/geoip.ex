defmodule Erlangelist.GeoIp do
  require Logger

  def country(ip) do
    case Erlangelist.run_limited(:geoip_query, fn -> get_country(ip) end) do
      {:ok, value} -> value
      _ -> nil
    end
  end

  defp get_country(ip) do
    try do
      case fetch(ip)["country_name"] do
        "" -> nil
        other -> other
      end
    catch type, error ->
      Logger.error(inspect({type, error, System.stacktrace}))
      nil
    end
  end

  defp fetch(ip) do
    %HTTPoison.Response{status_code: 200, body: body} =
      HTTPoison.get!("#{geoip_site_url}/json/#{ip}", timeout: :timer.seconds(1))

    Poison.decode!(body)
  end

  defp geoip_site_url, do: "http://#{Erlangelist.app_env!(:peer_ip)}:#{Erlangelist.app_env!(:geo_ip)}"
end