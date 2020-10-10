defmodule Erlangelist.Web.Dashboard.Router do
  use Phoenix.Router
  import Phoenix.Controller
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
  end

  live_dashboard "/", metrics: Erlangelist.Web.Dashboard.Telemetry
end
