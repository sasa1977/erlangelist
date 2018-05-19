defmodule Erlangelist.AcmeServer do
  @doc false
  def child_spec(_opts) do
    AcmeServer.Standalone.child_spec(
      adapter: {Plug.Adapters.Cowboy, scheme: :http, options: [port: port(), acceptors: 5]},
      dns: dns()
    )
  end

  def directory_url(), do: "http://localhost:#{port()}/directory"

  defp port(), do: 20081

  defp dns() do
    ErlangelistWeb.Endpoint.domains()
    |> Enum.map(&{&1, "localhost:#{ErlangelistWeb.Endpoint.http_port()}"})
    |> Enum.into(%{})
  end
end
