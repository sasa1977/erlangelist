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
    {:ok, geoip_site} = Application.fetch_env(:erlangelist, :geoip_site)

    ip_string =
      ip
      |> Tuple.to_list
      |> Enum.join(".")

    %HTTPoison.Response{
      status_code: 200,
      body: body
    } = HTTPoison.get!("http://#{geoip_site}:5458/json/#{ip_string}")

    Poison.decode!(body)["country_name"]
  end
end