defmodule Erlangelist.GeoIp do
  if Mix.env == :dev do
    def country(_), do: ""
  else
    def country(ip) do
      {:ok, json_data} = fetch(ip, :timer.seconds(1))
      json_data["country_name"]
    end
  end

  def fetch(ip, timeout) do
    ConCache.get_or_store(:geoip_cache, ip, fn ->
      case HTTPoison.get("#{geoip_site_url}/json/#{ip}", timeout: timeout) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Poison.decode(body) do
            {:ok, _} = success -> success
            other -> {:error, other}
          end
        other ->
          {:error, other}
      end
    end)
  end

  defp geoip_site_url, do: "http://#{Erlangelist.app_env!(:peer_ip)}:#{Erlangelist.app_env!(:geo_ip)}"
end