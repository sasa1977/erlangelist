defmodule Erlangelist.CookieCompliance do
  @behaviour Plug

  require Logger
  alias Erlangelist.GeoIp

  def init(opts), do: opts

  def call(conn, _config) do
    if conn.cookies["cookies"] == nil && !explicit_opt_in_needed?(conn) do
      # No need to explicitly opt in -> store cookie for future reference.
      Plug.Conn.put_resp_cookie(conn, "cookies", "true")
    else
      conn
    end
  end

  defp explicit_opt_in_needed?(conn) do
    try do
      conn.remote_ip
      |> Tuple.to_list
      |> Enum.join(".")
      |> GeoIp.fetch(:timer.seconds(1))
      |> from_eu?
    catch type, error ->
      # Bypassing "let-it-crash", since this is not critical. Whatever goes
      # wrong here, we pessimistically conclude that the visitor needs
      # to opt in.
      Logger.error("Error fetching geolocation: #{inspect {type, error}}")
      true
    end
  end

  eu_country_codes = [
    "BE",
    "BG",
    "CZ",
    "DK",
    "DE",
    "EE",
    "HR",
    "IE",
    "EL",
    "ES",
    "FR",
    "IT",
    "CY",
    "LV",
    "LT",
    "LU",
    "HU",
    "MT",
    "NL",
    "AT",
    "PL",
    "PT",
    "RO",
    "SI",
    "SK",
    "FI",
    "SE",
    "UK",
    "EU",
    ""
    ]

  for country_code <- eu_country_codes do
    defp from_eu?({:ok, %{"country_code" => unquote(country_code)}}), do: true
  end
  defp from_eu?({:ok, _}), do: false
  defp from_eu?(_), do: true
end