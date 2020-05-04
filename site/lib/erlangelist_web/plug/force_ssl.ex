defmodule ErlangelistWeb.Plug.ForceSSL do
  @behaviour Plug

  @impl Plug
  def init(endpoint), do: endpoint

  @impl Plug
  def call(%{scheme: :https} = conn, _endpoint), do: conn
  def call(conn, endpoint), do: Plug.SSL.call(conn, Plug.SSL.init(host: https_host(endpoint), log: :debug, exclude: []))

  defp https_host(endpoint) do
    host = Keyword.fetch!(endpoint.config(:url), :host)
    port = Keyword.get(endpoint.config(:https), :port, 443)
    "#{host}:#{port}"
  end
end
