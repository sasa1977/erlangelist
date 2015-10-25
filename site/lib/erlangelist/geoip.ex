defmodule Erlangelist.GeoIp do
  require Logger

  def country(ip) do
    empty_to_nil(fetch(ip)["country_name"])
  end

  def country_code(ip) do
    empty_to_nil(fetch(ip)["country_code"])
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(x), do: x

  defp fetch(ip) do
    try do
      case Erlangelist.run_limited(:geoip_query, fn -> do_fetch(ip) end) do
        {:ok, value} -> value
        _ -> nil
      end
    catch type, error ->
      Logger.error(inspect({type, error, System.stacktrace}))
      %{}
    end
  end

  defp do_fetch(ip) do
    ConCache.get_or_store(:geoip_cache, ip,
      fn ->
        %HTTPoison.Response{status_code: 200, body: body} =
          HTTPoison.get!("#{geoip_site_url}/json/#{ip}", timeout: :timer.seconds(1))

        Poison.decode!(body)
      end
    )
  end

  defp geoip_site_url, do: "http://#{Erlangelist.app_env!(:peer_ip)}:#{Erlangelist.app_env!(:geo_ip)}"
end