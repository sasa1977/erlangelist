defmodule ErlangelistWeb.Plug.ForceSSL do
  @behaviour Plug

  @impl Plug
  def init(opts), do: Map.new(opts)

  @impl Plug
  def call(%{scheme: :https} = conn, _opts), do: conn
  def call(conn, opts), do: Plug.SSL.call(conn, Plug.SSL.init(host: https_host(opts), log: :debug, exclude: []))

  defp https_host(opts) do
    host = Keyword.fetch!(opts.endpoint.config(:url), :host)
    port = opts.port
    if port == 443, do: host, else: "#{host}:#{port}"
  end
end
