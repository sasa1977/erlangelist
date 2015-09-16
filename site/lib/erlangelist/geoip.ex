defmodule Erlangelist.GeoIp do
  alias Erlangelist.PersistentCounterServer

  def report_metric(ip) do
    ip
    |> country
    |> report
  end

  defp report(nil), do: :ok
  defp report(""), do: :ok
  defp report(country) when is_binary(country) do
    PersistentCounterServer.inc("country_visit", country)
  end

  if Mix.env == :dev do
    defp country(_), do: ""
  else
    defp country(ip) do
      %HTTPoison.Response{
        status_code: 200,
        body: body
      } = HTTPoison.get!("#{geoip_site_url}/json/#{ip}")

      Poison.decode!(body)["country_name"]
    end

    defp geoip_site_url, do: "http://#{Erlangelist.app_env!(:peer_ip)}:5458"
  end
end