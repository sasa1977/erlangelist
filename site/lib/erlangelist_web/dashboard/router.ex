defmodule ErlangelistWeb.Dashboard.Router do
  use ErlangelistWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
  end

  live_dashboard "/", metrics: ErlangelistWeb.Dashboard.Telemetry
end
