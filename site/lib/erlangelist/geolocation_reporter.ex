defmodule Erlangelist.GeolocationReporter do
  require Logger
  use Workex

  alias Erlangelist.GeoIp
  alias Erlangelist.Model.CountryVisit
  alias Erlangelist.PersistentCounterServer

  def report(remote_ip) do
    Erlangelist.run_limited(
      :geolocation_reporter,
      fn -> Workex.push(__MODULE__, remote_ip) end
    )
  end

  def start_link do
    Workex.start_link(__MODULE__, nil, [], [name: __MODULE__])
  end

  def init(_), do: {:ok, nil}

  def handle(remote_ips, state) do
    remote_ips
    |> Enum.map(&Task.async(fn -> try_get_country(&1) end))
    |> Stream.map(&Task.await/1)
    |> Stream.filter(&(&1 != nil))
    |> Enum.each(&PersistentCounterServer.inc(CountryVisit, &1))

    {:ok, state, :hibernate}
  end

  def handle_message(_, state), do: {:ok, state}

  defp try_get_country(remote_ip) do
    try do
      remote_ip
      |> Erlangelist.Helper.ip_string
      |> GeoIp.country
    catch type, error ->
      Logger.error(inspect({type, error, System.stacktrace}))
      nil
    end
  end
end
