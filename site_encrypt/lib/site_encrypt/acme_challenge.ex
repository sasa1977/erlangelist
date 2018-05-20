defmodule SiteEncrypt.AcmeChallenge do
  @behaviour Plug

  @impl Plug
  def init(callback_mod), do: callback_mod

  @impl Plug
  def call(%{request_path: "/.well-known/acme-challenge/" <> challenge} = conn, callback_mod) do
    conn
    |> Plug.Conn.send_file(
      200,
      SiteEncrypt.Certbot.challenge_file(callback_mod.config(), challenge)
    )
    |> Plug.Conn.halt()
  end

  def call(conn, _endpoint), do: conn
end
