defmodule Erlangelist.GeoIp do
  alias Erlangelist.Metrics
  alias Erlangelist.OneOff

  def report_metric(ip) do
    OneOff.run(fn -> do_report_metric(ip) end)
  end

  defp do_report_metric(ip) do
    ip
    |> country
    |> report
  end

  defp report(nil), do: :ok
  defp report(""), do: :ok
  defp report(country) when is_binary(country) do
    Metrics.inc_spiral([:site, :visitors, :country, country])
  end

  defp country(ip) do
    %HTTPoison.Response{
      status_code: 200,
      body: body
    } = HTTPoison.get!("#{geoip_site_url}/json/#{ip}")

    Poison.decode!(body)["country_name"]
  end

  defp geoip_site_url, do: "http://#{Erlangelist.app_env!(:peer_ip)}:5458"
end