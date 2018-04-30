defmodule ErlangelistWeb.CookieCompliance do
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _config) do
    if !explicit_opt_in_needed?(conn) do
      # No need to explicitly opt in -> store cookie for future reference.
      Plug.Conn.put_resp_cookie(conn, "cookies", "true", path: "/", max_age: 60 * 60 * 24 * 365 * 30)
    else
      conn
    end
  end

  defp explicit_opt_in_needed?(conn) do
    case from_eu?(ErlangelistWeb.GeoIP.data(conn).country_code) do
      :no -> false
      :yes -> true
      :dont_know -> true
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
    "EU"
  ]

  defp from_eu?(nil), do: :dont_know
  defp from_eu?(""), do: :dont_know

  for country_code <- eu_country_codes do
    defp from_eu?(unquote(country_code)), do: :yes
  end

  defp from_eu?(_), do: :no
end
