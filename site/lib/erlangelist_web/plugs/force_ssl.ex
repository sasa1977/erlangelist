defmodule ErlangelistWeb.ForceSSL do
  import EnvHelper
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{scheme: :https} = conn, _opts), do: conn
  def call(conn, _opts), do: Plug.SSL.call(conn, Plug.SSL.init(host: https_host(), log: :debug, exclude: []))

  defp https_host() do
    to_string([
      Keyword.fetch!(ErlangelistWeb.Endpoint.config(:url), :host),
      env_specific(dev: ":20443", else: "")
    ])
  end
end
