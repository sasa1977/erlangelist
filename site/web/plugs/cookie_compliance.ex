defmodule Erlangelist.CookieCompliance do
  @behaviour Plug

  require Logger
  alias Erlangelist.GeoIp

  def init(opts), do: opts

  def call(conn, _config) do
    if conn.cookies["cookies"] == nil && !explicit_opt_in_needed?(conn) do
      # No need to explicitly opt in -> store cookie for future reference.
      Plug.Conn.put_resp_cookie(conn, "cookies", "true",
        path: "/", max_age: 60*60*24*365*30
      )
    else
      conn
    end
  end

  defp explicit_opt_in_needed?(conn) do
    try do
      conn.remote_ip
      |> Erlangelist.Helper.ip_string
      |> GeoIp.country
      |> from_eu?
      |> case do
            :no -> false
            :yes -> true
            :dont_know -> true
          end
    catch type, error ->
      # Bypassing "let-it-crash", since this is not critical. Whatever goes
      # wrong here, we pessimistically conclude that the visitor needs
      # to opt in.
      Logger.error(inspect({type, error, System.stacktrace}))
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

  defp from_eu?(nil), do: :dont_know

  for country_code <- eu_country_codes do
    defp from_eu?(%{"country_code" => unquote(country_code)}), do: :yes
  end

  defp from_eu?(_), do: :no
end