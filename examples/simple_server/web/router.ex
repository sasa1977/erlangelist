defmodule SimpleServer.Router do
  use SimpleServer.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", SimpleServer do
    pipe_through :api
  end
end
