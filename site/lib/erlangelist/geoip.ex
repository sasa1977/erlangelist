defmodule Erlangelist.GeoIp do
  alias Erlangelist.PersistentCounterServer
  alias Erlangelist.Model.CountryVisit

  def report_metric(ip) do
    ip
    |> country
    |> report
  end

  defp report(nil), do: :ok
  defp report(""), do: :ok
  defp report(country) when is_binary(country) do
    PersistentCounterServer.inc(CountryVisit, country)
  end

  if Mix.env == :dev do
    defp country(_), do: ""
  else
    defp country(ip) do
      {:ok, json_data} = fetch(ip, :timer.seconds(1))
      json_data["country_name"]
    end
  end

  def fetch(ip, timeout) do
    case HTTPoison.get("#{geoip_site_url}/json/#{ip}", timeout: timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, _} = success -> success
          other -> {:error, other}
        end
      other ->
        {:error, other}
    end
  end

  defp geoip_site_url, do: "http://#{Erlangelist.app_env!(:peer_ip)}:5458"
end