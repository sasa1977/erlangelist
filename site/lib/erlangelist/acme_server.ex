defmodule Erlangelist.AcmeServer do
  def directory_url(), do: "http://localhost:#{port()}/directory"

  defp port(), do: 20081

  @doc false
  def child_spec(_opts) do
    AcmeServer.Standalone.child_spec(
      adapter: {Plug.Adapters.Cowboy, scheme: :http, options: [port: port(), acceptors: 5]},
      dns: %{"localhost" => "localhost:20080"}
    )
  end
end
