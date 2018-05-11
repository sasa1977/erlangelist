defmodule SiteEncrypt.AcmeChallenge do
  @behaviour Plug

  @impl Plug
  def init(endpoint), do: endpoint

  @impl Plug
  def call(%{request_path: "/.well-known/acme-challenge/" <> challenge} = conn, endpoint) do
    conn
    |> Plug.Conn.send_file(
      200,
      SiteEncrypt.Certbot.challenge_file(endpoint.certbot_config(), challenge)
    )
    |> Plug.Conn.halt()
  end

  def call(conn, _endpoint), do: conn
end
