defmodule ErlangelistWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :erlangelist

  socket("/socket", ErlangelistWeb.UserSocket)

  plug(Plug.Static, at: "/", from: :erlangelist, gzip: false, only: ~w(css fonts images js favicon.ico robots.txt))

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Logger, log: :debug)

  plug(SiteEncrypt.AcmeChallenge, ErlangelistWeb.Site)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(ErlangelistWeb.MovePermanently, from: "theerlangelist.com", to: "www.theerlangelist.com")

  plug(ErlangelistWeb.Router)

  def init(_key, phoenix_defaults), do: {:ok, ErlangelistWeb.EndpointConfig.config(phoenix_defaults)}
end
